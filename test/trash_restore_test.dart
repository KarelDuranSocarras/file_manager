import 'dart:io';

import 'package:file_manager/features/sync/data/datasources/app_database.dart';
import 'package:file_manager/features/sync/data/datasources/drive_api_client.dart';
import 'package:file_manager/features/sync/data/repositories/sync_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'sync_repository_test.dart';

void main() {
  late Directory tempDir;
  late AppDatabase db;
  late FakeDriveClient drive;
  late SyncRepository repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('respaldo_test');
    db = await AppDatabase.open(':memory:');
    drive = FakeDriveClient();
    repo = SyncRepository(db, drive);
    await repo.setConfiguredFolder(tempDir.path);
  });

  tearDown(() async {
    await db.close();
    await tempDir.delete(recursive: true);
  });

  test('borrado local envía a papelera y deshacer recupera el archivo',
      () async {
    final file = File('${tempDir.path}/documento.txt')
      ..writeAsStringSync('contenido');

    await repo.scanAndEnqueue();
    await repo.processQueue();
    await file.delete();

    await repo.detectLocalDeletions();

    expect(drive.trashedIds, isNotEmpty);
    expect(await repo.localUploadCount(), 0);
    final trash = await repo.trashEntries();
    expect(trash.length, 1);
    expect(trash.first.path, file.path);

    await repo.undoTrashEntry(trash.first);

    expect(drive.untrashedIds, drive.trashedIds);
    expect(file.existsSync(), isTrue);
    expect(file.readAsStringSync(), contains('restaurado-'));
    expect(await repo.localUploadCount(), 1);
    expect(await repo.trashEntries(), isEmpty);
  });

  test('la purga elimina definitivamente solo lo vencido', () async {
    await db.addTrashEntry(
      path: '${tempDir.path}/viejo.txt',
      driveFileId: 'id-viejo',
      name: 'viejo.txt',
      trashedAt: DateTime.now().subtract(const Duration(days: 16)),
    );
    await db.addTrashEntry(
      path: '${tempDir.path}/nuevo.txt',
      driveFileId: 'id-nuevo',
      name: 'nuevo.txt',
    );

    await repo.purgeExpiredTrash();

    expect(drive.deletedIds, ['id-viejo']);
    final trash = await repo.trashEntries();
    expect(trash.length, 1);
    expect(trash.first.driveFileId, 'id-nuevo');
  });

  test('restauración completa evita sobreescribir archivos existentes',
      () async {
    final existing = File('${tempDir.path}/existente.txt')
      ..writeAsStringSync('local');

    drive.backupFiles = const [
      DriveEntry(id: 'd1', name: 'a.txt', relativeSegments: ['sub']),
      DriveEntry(id: 'd2', name: 'existente.txt'),
    ];

    bool canceled = false;
    final result = await repo.restoreAll(
      isCanceled: () => canceled,
    );

    expect(result.total, 2);
    expect(result.restored, 1);
    expect(result.skipped, 1);

    final restored = File('${tempDir.path}/sub/a.txt');
    expect(restored.existsSync(), isTrue);
    expect(restored.readAsStringSync(), contains('restaurado-d1'));
    expect(existing.readAsStringSync(), 'local');

    final record = await db.getUpload(restored.path);
    expect(record, isNotNull);
    expect(record!.driveFileId, 'd1');
  });

  test('la restauración se puede cancelar a mitad de camino', () async {
    drive.backupFiles = List.generate(
      4,
      (i) => DriveEntry(id: 'd$i', name: 'f$i.txt'),
    );

    var calls = 0;
    final result = await repo.restoreAll(
      isCanceled: () => ++calls > 2,
    );

    expect(result.restored, 2);
    expect(result.total, 4);
  });

  test('cuenta archivos locales y en la nube para la oferta', () async {
    File('${tempDir.path}/nuevo.txt').writeAsStringSync('x');
    drive.backupFiles = const [
      DriveEntry(id: 'd1', name: 'nube.txt'),
    ];

    expect(await repo.localUploadCount(), 0);
    expect(await repo.cloudBackupFileCount(), 1);

    await repo.scanAndEnqueue();
    await repo.processQueue();
    expect(await repo.localUploadCount(), 1);
  });
}
