import 'dart:io';

import 'package:path/path.dart' as p;

import '../../domain/models/activity_entry.dart';
import '../../domain/models/trash_entry.dart';
import '../../domain/models/upload_record.dart';
import '../../domain/services/change_detector.dart';
import '../../domain/services/exclusion_rules.dart';
import '../../domain/services/sync_exceptions.dart';
import '../datasources/app_database.dart';
import '../datasources/drive_api_client.dart';

class ScanResult {
  const ScanResult({
    required this.totalFiles,
    required this.enqueued,
    required this.unchanged,
    required this.skippedLarge,
    required this.deferred,
    required this.excluded,
  });

  final int totalFiles;
  final int enqueued;
  final int unchanged;
  final int skippedLarge;
  final int deferred;
  final int excluded;

  static const ScanResult empty = ScanResult(
    totalFiles: 0,
    enqueued: 0,
    unchanged: 0,
    skippedLarge: 0,
    deferred: 0,
    excluded: 0,
  );
}

enum QuotaLevel { ok, warning, critical, full }

class RestoreResult {
  const RestoreResult({
    required this.restored,
    required this.skipped,
    required this.total,
  });

  final int restored;
  final int skipped;
  final int total;
}

class SyncRepository {
  SyncRepository(
    this._db,
    this._drive, {
    this.changeDetector = const ChangeDetector(),
    this.exclusionRules = const ExclusionRules(),
    this.maxFileSizeBytes = defaultMaxFileSizeBytes,
    this.maxAttempts = 3,
    this.trashRetention = const Duration(days: 15),
  });

  static const int defaultMaxFileSizeBytes = 100 * 1024 * 1024;

  final int maxFileSizeBytes;
  final int maxAttempts;
  final Duration trashRetention;

  final AppDatabase _db;
  final DriveApiClient _drive;
  final ChangeDetector changeDetector;
  final ExclusionRules exclusionRules;
  final Set<String> _warnedOversize = {};

  Future<String?> configuredFolder() => _db.getConfig('folder_path');

  Future<void> setConfiguredFolder(String path) =>
      _db.setConfig('folder_path', path);

  /// Intervalo de escaneo en minutos (ajustes, §2.5); por defecto 15.
  Future<int> scanIntervalMinutes() async =>
      int.tryParse(await _db.getConfig('scan_interval_minutes') ?? '') ?? 15;

  Future<void> setScanIntervalMinutes(int minutes) =>
      _db.setConfig('scan_interval_minutes', '$minutes');

  /// Exclusiones personalizadas del usuario: '.log' extensión, resto
  /// se interpreta como parte de nombre (§2.5).
  Future<List<String>> customExclusions() async {
    final raw = await _db.getConfig('custom_exclusions');
    if (raw == null || raw.trim().isEmpty) return const [];
    return raw
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  Future<void> setCustomExclusions(List<String> values) =>
      _db.setConfig('custom_exclusions', values.join(','));

  Future<ExclusionRules> _loadExclusionRules() async {
    final custom = await customExclusions();
    return ExclusionRules(
      customExtensions: custom.where((s) => s.startsWith('.')).toList(),
      customNameParts: custom.where((s) => !s.startsWith('.')).toList(),
    );
  }

  Future<ScanResult> scanAndEnqueue({Duration minAge = Duration.zero}) async {
    final folder = await configuredFolder();
    if (folder == null) return ScanResult.empty;
    final root = Directory(folder);
    if (!await root.exists()) {
      throw SourceFolderMissingException(folder);
    }
    var total = 0, enqueued = 0, unchanged = 0, skippedLarge = 0;
    var deferred = 0, excluded = 0;
    final rules = await _loadExclusionRules();

    Future<void> walk(Directory dir) async {
      try {
        await for (final entity in dir.list(followLinks: false)) {
          if (entity is Link) {
            excluded++;
            continue;
          }
          if (rules.isExcluded(entity.path)) {
            excluded++;
            continue;
          }
          if (entity is Directory) {
            await walk(entity);
            continue;
          }
          if (entity is! File) continue;
          total++;
          final FileStat stat;
          try {
            stat = await entity.stat();
          } on FileSystemException {
            excluded++;
            continue;
          }
          if (stat.size > maxFileSizeBytes) {
            skippedLarge++;
            await _warnOversize(entity.path);
            continue;
          }
          if (minAge > Duration.zero &&
              DateTime.now().isBefore(stat.modified.add(minAge))) {
            deferred++;
            continue;
          }
          final queued = await _classifyAndEnqueue(
            entity.path,
            stat.size,
            stat.modified.millisecondsSinceEpoch,
          );
          if (queued) {
            enqueued++;
          } else {
            unchanged++;
          }
        }
      } on FileSystemException {
        await _db.logActivity(ActivityEntry(
          type: ActivityType.warning,
          message: 'No se pudo leer la carpeta durante el escaneo',
          path: dir.path,
          createdAt: DateTime.now(),
        ));
      }
    }

    await walk(root);
    return ScanResult(
      totalFiles: total,
      enqueued: enqueued,
      unchanged: unchanged,
      skippedLarge: skippedLarge,
      deferred: deferred,
      excluded: excluded,
    );
  }

  Future<void> enqueueFile(String path) async {
    final folder = await configuredFolder();
    if (folder == null) return;
    final rules = await _loadExclusionRules();
    if (rules.isExcluded(path)) return;
    final file = File(path);
    final FileStat stat;
    try {
      stat = await file.stat();
    } on FileSystemException {
      return;
    }
    if (stat.type == FileSystemEntityType.notFound) return;
    if (stat.size > maxFileSizeBytes) {
      await _warnOversize(path);
      return;
    }
    await _classifyAndEnqueue(
      path,
      stat.size,
      stat.modified.millisecondsSinceEpoch,
    );
  }

  /// Detecta archivos locales borrados y manda su copia de Drive a la
  /// papelera (acuerdo v1 §2.4). Sin conexión, se detiene y reintenta luego.
  Future<void> detectLocalDeletions() async {
    final folder = await configuredFolder();
    if (folder == null) return;
    final root = p.normalize(folder);
    for (final record in await _db.allUploads()) {
      if (!p.isWithin(root, record.path) || record.driveFileId == null) {
        continue;
      }
      if (await File(record.path).exists()) continue;
      try {
        await _drive.trashFile(record.driveFileId!);
      } on DriveNetworkException {
        return;
      } on DriveApiException {
        return;
      }
      await _db.addTrashEntry(
        path: record.path,
        driveFileId: record.driveFileId!,
        name: p.basename(record.path),
      );
      await _db.deleteUpload(record.path);
      await _db.logActivity(ActivityEntry(
        type: ActivityType.info,
        message: 'Archivo enviado a la papelera (borrado local)',
        path: record.path,
        createdAt: DateTime.now(),
      ));
    }
  }

  /// Elimina definitivamente la papelera vencida (15 días, §2.4).
  Future<void> purgeExpiredTrash() async {
    final cutoff = DateTime.now().subtract(trashRetention);
    for (final entry in await _db.expiredTrash(cutoff)) {
      try {
        await _drive.deleteFile(entry.driveFileId);
      } on DriveNetworkException {
        return;
      } on DriveApiException {
        // El archivo ya no existe en Drive: igual se limpia el registro.
      }
      await _db.removeTrashEntry(entry.id!);
      await _db.logActivity(ActivityEntry(
        type: ActivityType.info,
        message: 'Papelera: eliminación definitiva tras 15 días',
        path: entry.path,
        createdAt: DateTime.now(),
      ));
    }
  }

  Future<List<TrashEntry>> trashEntries() => _db.trashEntries();

  /// Deshacer: devuelve la copia a la nube activa y, si el archivo ya no
  /// existe localmente, lo descarga a su ruta original (§7.25).
  Future<void> undoTrashEntry(TrashEntry entry) async {
    await _drive.untrashFile(entry.driveFileId);
    final file = File(entry.path);
    if (!await file.exists()) {
      await file.parent.create(recursive: true);
      await _drive.downloadFile(
        fileId: entry.driveFileId,
        savePath: entry.path,
      );
      final stat = await file.stat();
      await _db.upsertUpload(UploadRecord(
        path: entry.path,
        size: stat.size,
        modifiedAtMs: stat.modified.millisecondsSinceEpoch,
        driveFileId: entry.driveFileId,
        uploadedAtMs: DateTime.now().millisecondsSinceEpoch,
      ));
    }
    await _db.removeTrashEntry(entry.id!);
    await _db.logActivity(ActivityEntry(
      type: ActivityType.info,
      message: 'Archivo recuperado de la papelera',
      path: entry.path,
      createdAt: DateTime.now(),
    ));
  }

  Future<void> emptyTrash() async {
    for (final entry in await _db.trashEntries()) {
      try {
        await _drive.deleteFile(entry.driveFileId);
      } on DriveNetworkException {
        return;
      } on DriveApiException {
        // Ya no existe en Drive: igual se limpia el registro.
      }
      await _db.removeTrashEntry(entry.id!);
    }
    await _db.logActivity(ActivityEntry(
      type: ActivityType.info,
      message: 'Papelera vaciada',
      createdAt: DateTime.now(),
    ));
  }

  Future<int> localUploadCount() => _db.uploadCount();

  Future<int> cloudBackupFileCount() async =>
      (await _drive.listBackupFiles()).length;

  Future<void> logWarning(String message) => _db.logActivity(ActivityEntry(
        type: ActivityType.warning,
        message: message,
        createdAt: DateTime.now(),
      ));

  static const String _quotaWarnKey = 'quota_warned_level';

  /// Aviso proactivo de cuota (§6.20): devuelve el mensaje si hay que
  /// avisar (una sola vez por nivel alcanzado); null si nada que avisar.
  Future<String?> checkQuota() async {
    final info = await _drive.quota();
    final limit = info.limitBytes;
    if (limit == null || limit <= 0) return null;
    final ratio = info.usageBytes / limit;
    final level = ratio >= 0.999
        ? QuotaLevel.full
        : ratio >= 0.95
            ? QuotaLevel.critical
            : ratio >= 0.80
                ? QuotaLevel.warning
                : QuotaLevel.ok;
    final lastStored = await _db.getConfig(_quotaWarnKey);
    final lastIndex = lastStored == null ? null : int.tryParse(lastStored);
    if (level == QuotaLevel.ok) {
      if (lastIndex != null) await _db.removeConfig(_quotaWarnKey);
      return null;
    }
    if (lastIndex != null && level.index <= lastIndex) return null;
    await _db.setConfig(_quotaWarnKey, '${level.index}');
    final percent = (ratio * 100).round();
    final message = switch (level) {
      QuotaLevel.warning =>
        'Cuota de Google Drive al $percent%: poco espacio disponible',
      QuotaLevel.critical =>
        'Cuota de Google Drive al $percent%: queda muy poco espacio',
      QuotaLevel.full =>
        'Cuota de Google Drive agotada: no se pueden subir más archivos',
      QuotaLevel.ok => null,
    };
    if (message != null) await logWarning(message);
    return message;
  }

  /// La carpeta local desapareció y el usuario decidió borrar: toda la
  /// copia en la nube pasa a la papelera de 15 días (§6.21).
  Future<void> trashAllCloudCopies() async {
    for (final record in await _db.allUploads()) {
      final fileId = record.driveFileId;
      if (fileId == null) continue;
      try {
        await _drive.trashFile(fileId);
      } on DriveNetworkException {
        return;
      } on DriveApiException {
        // Ya no existe en Drive: igual se registra como papelera.
      }
      await _db.addTrashEntry(
        path: record.path,
        driveFileId: fileId,
        name: p.basename(record.path),
      );
      await _db.deleteUpload(record.path);
    }
    await _db.clearQueue();
    await _db.logActivity(ActivityEntry(
      type: ActivityType.info,
      message:
          'Copia en la nube enviada a la papelera: la carpeta local se '
          'eliminó',
      createdAt: DateTime.now(),
    ));
  }

  /// Restauración completa hacia la carpeta original (§7.23–7.24).
  /// No sobreescribe archivos locales existentes.
  Future<RestoreResult> restoreAll({
    void Function(int done, int total)? onProgress,
    bool Function()? isCanceled,
  }) async {
    final folder = await configuredFolder();
    if (folder == null) {
      throw const DriveApiException('No hay carpeta configurada');
    }
    final entries = await _drive.listBackupFiles();
    var restored = 0, skipped = 0;
    for (final (index, entry) in entries.indexed) {
      if (isCanceled?.call() ?? false) break;
      final localPath = p.joinAll([folder, ...entry.relativeSegments, entry.name]);
      final file = File(localPath);
      if (await file.exists()) {
        skipped++;
        await _db.logActivity(ActivityEntry(
          type: ActivityType.warning,
          message: 'Restauración: archivo local existente no se tocó',
          path: localPath,
          createdAt: DateTime.now(),
        ));
      } else {
        await file.parent.create(recursive: true);
        try {
          await _drive.downloadFile(
            fileId: entry.id,
            savePath: localPath,
          );
        } on DriveNetworkException {
          await _db.logActivity(ActivityEntry(
            type: ActivityType.warning,
            message: 'Restauración interrumpida por falta de conexión',
            path: localPath,
            createdAt: DateTime.now(),
          ));
          rethrow;
        }
        final stat = await file.stat();
        await _db.upsertUpload(UploadRecord(
          path: localPath,
          size: stat.size,
          modifiedAtMs: stat.modified.millisecondsSinceEpoch,
          driveFileId: entry.id,
          uploadedAtMs: DateTime.now().millisecondsSinceEpoch,
        ));
        await _db.logActivity(ActivityEntry(
          type: ActivityType.info,
          message: 'Archivo restaurado',
          path: localPath,
          createdAt: DateTime.now(),
        ));
        restored++;
      }
      onProgress?.call(index + 1, entries.length);
    }
    return RestoreResult(
      restored: restored,
      skipped: skipped,
      total: entries.length,
    );
  }

  Future<int> processQueue({
    void Function(String fileName)? onUploading,
  }) async {
    var uploaded = 0;
    while (true) {
      final items = await _db.pendingItems(limit: 5);
      if (items.isEmpty) break;
      var progressed = false;
      for (final item in items) {
        if (item.attempts >= maxAttempts) {
          await _db.removeQueueItem(item.id);
          await _db.logActivity(ActivityEntry(
            type: ActivityType.error,
            message: 'Archivo saltado tras $maxAttempts intentos fallidos',
            path: item.path,
            createdAt: DateTime.now(),
          ));
          progressed = true;
          continue;
        }
        final file = File(item.path);
        if (!await file.exists()) {
          await _db.removeQueueItem(item.id);
          progressed = true;
          continue;
        }
        final name = p.basename(item.path);
        onUploading?.call(name);
        final previous = await _db.getUpload(item.path);
        try {
          final driveFileId = await _drive.uploadFile(
            name: name,
            filePath: item.path,
            relativeDirs: await _relativeDirsFor(item.path),
            existingFileId: previous?.driveFileId,
          );
          await _db.markUploaded(item: item, driveFileId: driveFileId);
          await _db.logActivity(ActivityEntry(
            type: ActivityType.info,
            message: 'Archivo subido a Drive',
            path: item.path,
            createdAt: DateTime.now(),
          ));
          uploaded++;
          progressed = true;
        } on DriveNetworkException {
          rethrow;
        } on DriveQuotaException {
          await _db.logActivity(ActivityEntry(
            type: ActivityType.warning,
            message: 'Cuota de Google Drive agotada: se reintentará más tarde',
            path: item.path,
            createdAt: DateTime.now(),
          ));
          return uploaded;
        } on DriveAuthException {
          await _db.logActivity(ActivityEntry(
            type: ActivityType.error,
            message: 'Credenciales de Google Drive inválidas',
            path: item.path,
            createdAt: DateTime.now(),
          ));
          rethrow;
        } on DriveApiException catch (e) {
          await _db.incrementAttempts(item.id);
          await _db.logActivity(ActivityEntry(
            type: ActivityType.warning,
            message:
                'Fallo al subir (intento ${item.attempts + 1}): ${e.message}',
            path: item.path,
            createdAt: DateTime.now(),
          ));
          progressed = true;
        }
      }
      if (!progressed) break;
    }
    return uploaded;
  }

  Future<List<String>> _relativeDirsFor(String path) async {
    final folder = await configuredFolder();
    if (folder == null) return const [];
    final relative = p.relative(path, from: folder);
    if (p.dirname(relative) == '.') return const [];
    return p.split(p.dirname(relative)).toList();
  }

  Future<bool> _classifyAndEnqueue(
    String path,
    int size,
    int modifiedMs,
  ) async {
    final previous = await _db.getUpload(path);
    final change = changeDetector.classify(
      localSize: size,
      localModifiedMs: modifiedMs,
      uploadedSize: previous?.size,
      uploadedModifiedMs: previous?.modifiedAtMs,
    );
    if (change == FileChangeType.unchanged) return false;
    await _db.enqueue(path, size, modifiedMs);
    return true;
  }

  Future<void> _warnOversize(String path) async {
    if (!_warnedOversize.add(path)) return;
    await _db.logActivity(ActivityEntry(
      type: ActivityType.warning,
      message: 'Archivo omitido: supera el límite de '
          '${maxFileSizeBytes ~/ (1024 * 1024)} MB',
      path: path,
      createdAt: DateTime.now(),
    ));
  }
}
