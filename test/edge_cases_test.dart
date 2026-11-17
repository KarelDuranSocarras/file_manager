import 'dart:io';

import 'package:file_manager/features/sync/data/datasources/app_database.dart';
import 'package:file_manager/features/sync/data/datasources/drive_api_client.dart';
import 'package:file_manager/features/sync/data/repositories/sync_repository.dart';
import 'package:file_manager/features/sync/domain/services/sync_exceptions.dart';
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

  test('cuota al 80% avisa una vez y se rearma al bajar', () async {
    final drive = FakeDriveClient()
      ..quotaInfo = const DriveQuotaInfo(
        usageBytes: 80,
        limitBytes: 100,
      );
    final repo = SyncRepository(db, drive);
    await repo.setConfiguredFolder(tempDir.path);

    final first = await repo.checkQuota();
    expect(first, contains('80%'));

    final second = await repo.checkQuota();
    expect(second, isNull);

    // Baja al 50% y vuelve a subir al 85%: avisa de nuevo.
    drive.quotaInfo = const DriveQuotaInfo(usageBytes: 50, limitBytes: 100);
    expect(await repo.checkQuota(), isNull);
    drive.quotaInfo = const DriveQuotaInfo(usageBytes: 85, limitBytes: 100);
    expect(await repo.checkQuota(), contains('85%'));
  });

  test('cuota llena avisa crítico y las subas se detienen sin perder cola',
      () async {
    File('${tempDir.path}/a.txt').writeAsStringSync('x');
    final drive = FakeDriveClient()
      ..quotaInfo = const DriveQuotaInfo(usageBytes: 100, limitBytes: 100)
      ..failUploads = true;
    final repo = SyncRepository(db, drive);
    await repo.setConfiguredFolder(tempDir.path);

    final message = await repo.checkQuota();
    expect(message, contains('agotada'));

    await repo.scanAndEnqueue();
    final uploaded = await repo.processQueue();
    expect(uploaded, 0);
    expect(await db.pendingItems(), hasLength(1));

    final activity = await db.recentActivity();
    expect(
      activity.any((a) => a.message.contains('Cuota de Google Drive agotada')),
      isTrue,
    );
  });

  test('cuota sin límite (Workspace) nunca avisa', () async {
    final drive = FakeDriveClient()
      ..quotaInfo = const DriveQuotaInfo(usageBytes: 99999);
    final repo = SyncRepository(db, drive);
    expect(await repo.checkQuota(), isNull);
  });

  test('sin conexión la cola queda intacta y luego sube al reconectar',
      () async {
    File('${tempDir.path}/a.txt').writeAsStringSync('x');
    final drive = FakeDriveClient()..offline = true;
    final repo = SyncRepository(db, drive);
    await repo.setConfiguredFolder(tempDir.path);

    await repo.scanAndEnqueue();
    await expectLater(
      repo.processQueue(),
      throwsA(isA<DriveNetworkException>()),
    );
    expect(await db.pendingItems(), hasLength(1));

    drive.offline = false;
    expect(await repo.processQueue(), 1);
    expect(await db.pendingItems(), isEmpty);
  });

  test('borrar carpeta localmente envía toda la copia en la nube a papelera',
      () async {
    File('${tempDir.path}/a.txt').writeAsStringSync('x');
    final drive = FakeDriveClient();
    final repo = SyncRepository(db, drive);
    await repo.setConfiguredFolder(tempDir.path);

    await repo.scanAndEnqueue();
    await repo.processQueue();
    final record = await db.getUpload('${tempDir.path}/a.txt');
    expect(record, isNotNull);

    await repo.trashAllCloudCopies();

    expect(drive.trashedIds, [record!.driveFileId]);
    expect(await db.getUpload('${tempDir.path}/a.txt'), isNull);
    expect(await db.pendingItems(), isEmpty);
    final trash = await db.trashEntries();
    expect(trash, hasLength(1));
    expect(trash.first.name, 'a.txt');
  });

  test('las exclusiones personalizadas de ajustes se respetan al escanear',
      () async {
    File('${tempDir.path}/informe.log').writeAsStringSync('x');
    File('${tempDir.path}/importante.txt').writeAsStringSync('x');
    final drive = FakeDriveClient();
    final repo = SyncRepository(db, drive);
    await repo.setConfiguredFolder(tempDir.path);

    await repo.setCustomExclusions(['.log']);
    final result = await repo.scanAndEnqueue();

    expect(result.excluded, 1);
    expect(result.enqueued, 1);
    expect(await db.pendingItems(), hasLength(1));

    // Quitar la exclusión vuelve a considerar el .log como nuevo.
    await repo.setCustomExclusions([]);
    final second = await repo.scanAndEnqueue();
    expect(second.enqueued, 2);
    final pending = await db.pendingItems();
    expect(pending.any((item) => item.path.endsWith('informe.log')), isTrue);
  });
}
