import 'dart:async';
import 'dart:io';

import 'package:watcher/watcher.dart';

import '../../data/repositories/sync_repository.dart';
import '../services/sync_exceptions.dart';

sealed class SyncEngineEvent {
  const SyncEngineEvent();
}

class EngineNotConfigured extends SyncEngineEvent {
  const EngineNotConfigured();
}

class EngineScanning extends SyncEngineEvent {
  const EngineScanning();
}

class EngineUploading extends SyncEngineEvent {
  const EngineUploading(this.fileName);

  final String fileName;
}

class EngineUpToDate extends SyncEngineEvent {
  const EngineUpToDate({this.uploadedCount = 0});

  final int uploadedCount;
}

class EngineFolderMissing extends SyncEngineEvent {
  const EngineFolderMissing();
}

class EngineWaitingConnection extends SyncEngineEvent {
  const EngineWaitingConnection();
}

class EngineOfflineWarning extends SyncEngineEvent {
  const EngineOfflineWarning();
}

class EngineQuotaWarning extends SyncEngineEvent {
  const EngineQuotaWarning(this.message);

  final String message;
}

class EnginePaused extends SyncEngineEvent {
  const EnginePaused();
}

class EngineResumed extends SyncEngineEvent {
  const EngineResumed();
}

class EngineError extends SyncEngineEvent {
  const EngineError(this.message);

  final String message;
}

class EngineRestoring extends SyncEngineEvent {
  const EngineRestoring({required this.done, required this.total});

  final int done;
  final int total;
}

class EngineRestoreOffer extends SyncEngineEvent {
  const EngineRestoreOffer(this.fileCount);

  final int fileCount;
}

class SyncEngine {
  SyncEngine(
    this._repository, {
    this.scanInterval = const Duration(minutes: 15),
    this.stabilityWindow = const Duration(minutes: 2),
  });

  final SyncRepository _repository;
  Duration scanInterval;
  final Duration stabilityWindow;

  final StreamController<SyncEngineEvent> _events =
      StreamController<SyncEngineEvent>.broadcast();

  Stream<SyncEngineEvent> get events => _events.stream;

  Timer? _scanTimer;
  Timer? _stabilityTimer;
  Timer? _deletionTimer;
  StreamSubscription<WatchEvent>? _watchSub;
  final Map<String, FileStat?> _stability = {};
  bool _busy = false;
  bool _disposed = false;
  bool _restoreCanceled = false;
  DateTime? _lastDriveContact;
  DateTime? _startedAt;
  bool _offlineWarned = false;
  bool _paused = false;
  bool _autoSync = true;

  bool get isPaused => _paused;

  /// Pausa: no se escanea ni se sube; la cola se conserva (§5.15).
  void pause() {
    if (_paused) return;
    _paused = true;
    _emit(const EnginePaused());
  }

  void resume() {
    if (!_paused) return;
    _paused = false;
    _emit(const EngineResumed());
    syncNow();
  }

  Future<void> start() async {
    _startedAt = DateTime.now();
    final folder = await _repository.configuredFolder();
    if (folder == null) {
      _emit(const EngineNotConfigured());
      return;
    }
    scanInterval = Duration(
      minutes: await _repository.scanIntervalMinutes(),
    );
    _autoSync = await _repository.autoSyncEnabled();
    _watch(folder);
    await syncNow();
    _restartTimer();
  }

  /// Cambia el intervalo de escaneo desde ajustes y lo persiste (§2.5).
  Future<void> setScanInterval(Duration interval) async {
    scanInterval = interval;
    await _repository.setScanIntervalMinutes(interval.inMinutes);
    _restartTimer();
  }

  /// Activa/desactiva la sincronización automática por intervalo
  /// (ajustes). El watcher y "Sincronizar ahora" siguen funcionando.
  Future<void> setAutoSync(bool enabled) async {
    _autoSync = enabled;
    await _repository.setAutoSyncEnabled(enabled);
    _restartTimer();
  }

  void _restartTimer() {
    _scanTimer?.cancel();
    if (_autoSync && !_paused && !_disposed) {
      _scanTimer = Timer.periodic(scanInterval, (_) => syncNow());
    }
  }

  Future<void> chooseFolder(String path) async {
    await _repository.setConfiguredFolder(path);
    await _stopWatching();
    _watch(path);
    await syncNow();
    await _offerRestoreIfNeeded();
  }

  Future<void> syncNow() async {
    if (_busy || _paused || _disposed) return;
    _busy = true;
    try {
      _emit(const EngineScanning());
      await _repository.scanAndEnqueue(minAge: stabilityWindow);
      await _repository.detectLocalDeletions();
      final uploaded = await _repository.processQueue(
        onUploading: (name) => _emit(EngineUploading(name)),
      );
      _lastDriveContact = DateTime.now();
      _offlineWarned = false;
      try {
        await _repository.purgeExpiredTrash();
      } on DriveNetworkException {
        // La purga se reintenta en el próximo ciclo.
      } on DriveApiException {
        // Entradas de papelera ya inexistentes: se limpian solas.
      }
      try {
        final quotaMessage = await _repository.checkQuota();
        if (quotaMessage != null) _emit(EngineQuotaWarning(quotaMessage));
      } on DriveNetworkException {
        // Aviso de cuota se reintenta en el próximo ciclo.
      } on DriveApiException {
        // Sin datos de cuota: nada que avisar ahora.
      }
      _emit(EngineUpToDate(uploadedCount: uploaded));
    } on SourceFolderMissingException {
      _emit(const EngineFolderMissing());
    } on DriveAuthException catch (e) {
      _emit(EngineError(e.message));
    } on DriveNetworkException {
      await _handleOffline();
    } catch (e) {
      _emit(EngineError(e.toString()));
    } finally {
      _busy = false;
    }
  }

  /// Aviso único tras 1 hora sin poder contactar Drive (§6.19).
  Future<void> _handleOffline() async {
    if (!_offlineWarned) {
      final reference = _lastDriveContact ?? _startedAt ?? DateTime.now();
      if (DateTime.now().difference(reference) >= const Duration(hours: 1)) {
        _offlineWarned = true;
        await _repository.logWarning(
          'Sin conexión con Google Drive por más de 1 hora: '
          'los cambios quedan en cola',
        );
        _emit(const EngineOfflineWarning());
        return;
      }
    }
    _emit(const EngineWaitingConnection());
  }

  /// El usuario decidió borrar la carpeta local: la copia en la nube
  /// completa pasa a la papelera de 15 días (§6.21).
  Future<void> trashAllCloudCopies() async {
    if (_busy || _disposed) return;
    _busy = true;
    try {
      await _repository.trashAllCloudCopies();
    } on DriveNetworkException {
      // Sin red: se reintenta cuando el usuario lo pida de nuevo.
    } on DriveAuthException catch (e) {
      _emit(EngineError(e.message));
      return;
    } catch (e) {
      _emit(EngineError(e.toString()));
      return;
    } finally {
      _busy = false;
    }
    _emit(const EngineNotConfigured());
  }

  Future<void> restoreAll() async {
    if (_busy || _disposed) return;
    _busy = true;
    _restoreCanceled = false;
    try {
      _emit(const EngineRestoring(done: 0, total: 0));
      await _repository.restoreAll(
        onProgress: (done, total) =>
            _emit(EngineRestoring(done: done, total: total)),
        isCanceled: () => _restoreCanceled,
      );
      _emit(const EngineUpToDate());
    } on DriveNetworkException {
      _emit(const EngineError('Restauración interrumpida: sin conexión'));
    } on DriveAuthException catch (e) {
      _emit(EngineError(e.message));
    } catch (e) {
      _emit(EngineError(e.toString()));
    } finally {
      _busy = false;
    }
  }

  void cancelRestore() {
    _restoreCanceled = true;
  }

  Future<void> _offerRestoreIfNeeded() async {
    try {
      final localCount = await _repository.localUploadCount();
      if (localCount > 0) return;
      final cloudCount = await _repository.cloudBackupFileCount();
      if (cloudCount > 0) {
        _emit(EngineRestoreOffer(cloudCount));
      }
    } on DriveAuthException catch (e) {
      _emit(EngineError(e.message));
    } on DriveNetworkException {
      // Sin red: la oferta se reintenta en el próximo ciclo.
    } on DriveApiException {
      // No se pudo listar la nube: se omite la oferta.
    }
  }

  void _watch(String folder) {
    final dir = Directory(folder);
    if (!dir.existsSync()) return;
    final watcher = DirectoryWatcher(dir.path);
    _watchSub = watcher.events.listen(
      (event) {
        switch (event.type) {
          case ChangeType.ADD:
          case ChangeType.MODIFY:
            _stability[event.path] = null;
            _stabilityTimer ??= Timer.periodic(stabilityWindow, (_) {
              _checkStability();
            });
          case ChangeType.REMOVE:
            _deletionTimer?.cancel();
            _deletionTimer = Timer(
              stabilityWindow,
              () => _repository.detectLocalDeletions(),
            );
        }
      },
      onError: (Object e) {
        _emit(EngineError('Vigilancia de carpeta interrumpida: $e'));
      },
    );
  }

  Future<void> _checkStability() async {
    if (_stability.isEmpty || _busy || _paused) return;
    for (final path in List.of(_stability.keys)) {
      final seen = _stability[path];
      final FileStat stat;
      try {
        stat = await File(path).stat();
      } on FileSystemException {
        _stability.remove(path);
        continue;
      }
      if (stat.type == FileSystemEntityType.notFound) {
        _stability.remove(path);
        continue;
      }
      if (seen != null &&
          seen.size == stat.size &&
          seen.modified == stat.modified) {
        _stability.remove(path);
        await _repository.enqueueFile(path);
      } else {
        _stability[path] = stat;
      }
    }
  }

  Future<void> _stopWatching() async {
    await _watchSub?.cancel();
    _watchSub = null;
    _deletionTimer?.cancel();
    _deletionTimer = null;
  }

  void _emit(SyncEngineEvent event) {
    if (!_disposed && !_events.isClosed) {
      _events.add(event);
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _scanTimer?.cancel();
    _stabilityTimer?.cancel();
    await _stopWatching();
    await _events.close();
  }
}
