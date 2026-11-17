import 'dart:io';

import 'package:file_manager/features/sync/data/datasources/app_database.dart';
import 'package:file_manager/features/sync/data/repositories/sync_repository.dart';
import 'package:file_manager/features/sync/domain/services/sync_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'sync_repository_test.dart';

void main() {
  late Directory tempDir;
  late AppDatabase db;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('respaldo_test');
    db = await AppDatabase.open(':memory:');
  });

  tearDown(() async {
    await db.close();
    await tempDir.delete(recursive: true);
  });

  test('pausa detiene la sincronización y reanudar la reactiva', () async {
    final engine = SyncEngine(
      SyncRepository(db, FakeDriveClient()),
      scanInterval: const Duration(hours: 1),
    );
    final events = <SyncEngineEvent>[];
    final sub = engine.events.listen(events.add);

    await engine.start();
    await pumpEventQueue();
    expect(events.any((e) => e is EngineNotConfigured), isTrue);

    engine.pause();
    await pumpEventQueue();
    expect(engine.isPaused, isTrue);
    expect(events.any((e) => e is EnginePaused), isTrue);

    await engine.syncNow();
    await pumpEventQueue();
    expect(events.any((e) => e is EngineScanning), isFalse);

    engine.resume();
    await engine.events
        .firstWhere((e) => e is EngineUpToDate)
        .timeout(const Duration(seconds: 5));
    expect(engine.isPaused, isFalse);
    expect(events.any((e) => e is EngineResumed), isTrue);

    await sub.cancel();
    await engine.dispose();
  });
}
