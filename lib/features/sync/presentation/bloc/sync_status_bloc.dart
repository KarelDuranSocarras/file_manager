import 'dart:async';

import 'package:bloc/bloc.dart';

import '../../domain/services/sync_engine.dart';

sealed class SyncStatusEvent {
  const SyncStatusEvent();
}

final class SyncStatusStarted extends SyncStatusEvent {
  const SyncStatusStarted();
}

final class SyncNowRequested extends SyncStatusEvent {
  const SyncNowRequested();
}

final class FolderSelected extends SyncStatusEvent {
  const FolderSelected(this.path);

  final String path;
}

final class RestoreAllRequested extends SyncStatusEvent {
  const RestoreAllRequested();
}

final class CancelRestoreRequested extends SyncStatusEvent {
  const CancelRestoreRequested();
}

final class RestoreOfferDismissed extends SyncStatusEvent {
  const RestoreOfferDismissed();
}

final class FolderMissingTrashCloud extends SyncStatusEvent {
  const FolderMissingTrashCloud();
}

final class PauseSyncRequested extends SyncStatusEvent {
  const PauseSyncRequested();
}

final class ResumeSyncRequested extends SyncStatusEvent {
  const ResumeSyncRequested();
}

final class EngineEventArrived extends SyncStatusEvent {
  const EngineEventArrived(this.event);

  final SyncEngineEvent event;
}

sealed class SyncStatusState {
  const SyncStatusState();
}

final class SyncStatusInitial extends SyncStatusState {
  const SyncStatusInitial();
}

final class SyncStatusNotConfigured extends SyncStatusState {
  const SyncStatusNotConfigured();
}

final class SyncStatusScanning extends SyncStatusState {
  const SyncStatusScanning();
}

final class SyncStatusUpToDate extends SyncStatusState {
  const SyncStatusUpToDate();
}

final class SyncStatusUploading extends SyncStatusState {
  const SyncStatusUploading(this.fileName);

  final String fileName;
}

final class SyncStatusFolderMissing extends SyncStatusState {
  const SyncStatusFolderMissing();
}

final class SyncStatusError extends SyncStatusState {
  const SyncStatusError(this.message);

  final String message;
}

final class SyncStatusRestoring extends SyncStatusState {
  const SyncStatusRestoring({required this.done, required this.total});

  final int done;
  final int total;
}

final class SyncStatusRestoreOffer extends SyncStatusState {
  const SyncStatusRestoreOffer(this.fileCount);

  final int fileCount;
}

final class SyncStatusWaitingConnection extends SyncStatusState {
  const SyncStatusWaitingConnection();
}

final class SyncStatusOfflineWarning extends SyncStatusState {
  const SyncStatusOfflineWarning();
}

final class SyncStatusQuotaWarning extends SyncStatusState {
  const SyncStatusQuotaWarning(this.message);

  final String message;
}

final class SyncStatusPaused extends SyncStatusState {
  const SyncStatusPaused();
}

class SyncStatusBloc extends Bloc<SyncStatusEvent, SyncStatusState> {
  SyncStatusBloc(this._engine) : super(const SyncStatusInitial()) {
    on<SyncStatusStarted>(_onStarted);
    on<SyncNowRequested>(_onSyncNow);
    on<FolderSelected>(_onFolderSelected);
    on<RestoreAllRequested>(_onRestoreAll);
    on<CancelRestoreRequested>(_onCancelRestore);
    on<RestoreOfferDismissed>(_onRestoreOfferDismissed);
    on<FolderMissingTrashCloud>(_onFolderMissingTrashCloud);
    on<PauseSyncRequested>(_onPauseSync);
    on<ResumeSyncRequested>(_onResumeSync);
    on<EngineEventArrived>(_onEngineEvent);
  }

  final SyncEngine _engine;
  StreamSubscription<SyncEngineEvent>? _subscription;
  bool _started = false;

  Future<void> _onStarted(
    SyncStatusStarted event,
    Emitter<SyncStatusState> emit,
  ) async {
    if (_started) return;
    _started = true;
    _subscription = _engine.events.listen(
      (event) => add(EngineEventArrived(event)),
    );
    await _engine.start();
  }

  Future<void> _onSyncNow(
    SyncNowRequested event,
    Emitter<SyncStatusState> emit,
  ) async {
    await _engine.syncNow();
  }

  Future<void> _onFolderSelected(
    FolderSelected event,
    Emitter<SyncStatusState> emit,
  ) async {
    await _engine.chooseFolder(event.path);
  }

  Future<void> _onRestoreAll(
    RestoreAllRequested event,
    Emitter<SyncStatusState> emit,
  ) async {
    await _engine.restoreAll();
  }

  void _onCancelRestore(
    CancelRestoreRequested event,
    Emitter<SyncStatusState> emit,
  ) {
    _engine.cancelRestore();
  }

  void _onRestoreOfferDismissed(
    RestoreOfferDismissed event,
    Emitter<SyncStatusState> emit,
  ) {
    emit(const SyncStatusUpToDate());
  }

  Future<void> _onFolderMissingTrashCloud(
    FolderMissingTrashCloud event,
    Emitter<SyncStatusState> emit,
  ) async {
    await _engine.trashAllCloudCopies();
  }

  void _onPauseSync(
    PauseSyncRequested event,
    Emitter<SyncStatusState> emit,
  ) {
    _engine.pause();
  }

  void _onResumeSync(
    ResumeSyncRequested event,
    Emitter<SyncStatusState> emit,
  ) {
    _engine.resume();
  }

  void _onEngineEvent(
    EngineEventArrived event,
    Emitter<SyncStatusState> emit,
  ) {
    emit(switch (event.event) {
      EngineNotConfigured() => const SyncStatusNotConfigured(),
      EngineScanning() => const SyncStatusScanning(),
      EngineUploading(:final fileName) => SyncStatusUploading(fileName),
      EngineUpToDate() => const SyncStatusUpToDate(),
      EngineFolderMissing() => const SyncStatusFolderMissing(),
      EngineWaitingConnection() => const SyncStatusWaitingConnection(),
      EngineOfflineWarning() => const SyncStatusOfflineWarning(),
      EngineQuotaWarning(:final message) => SyncStatusQuotaWarning(message),
      EnginePaused() => const SyncStatusPaused(),
      EngineResumed() => const SyncStatusUpToDate(),
      EngineError(:final message) => SyncStatusError(message),
      EngineRestoring(:final done, :final total) => SyncStatusRestoring(
          done: done,
          total: total,
        ),
      EngineRestoreOffer(:final fileCount) =>
        SyncStatusRestoreOffer(fileCount),
    });
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    await super.close();
  }
}
