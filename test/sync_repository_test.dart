import 'dart:io';

import 'package:file_manager/features/sync/data/datasources/app_database.dart';
import 'package:file_manager/features/sync/data/datasources/drive_api_client.dart';
import 'package:file_manager/features/sync/data/repositories/sync_repository.dart';
import 'package:file_manager/features/sync/domain/services/sync_exceptions.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeDriveClient extends DriveApiClient {
  FakeDriveClient({this.failuresBeforeSuccess = 0})
      : super('test-id', 'test-secret', 'test-token');

  final int failuresBeforeSuccess;
  final List<String> uploadedNames = [];
  final List<String> trashedIds = [];
  final List<String> untrashedIds = [];
  final List<String> deletedIds = [];
  List<DriveEntry> backupFiles = const [];
  DriveQuotaInfo? quotaInfo;
  bool offline = false;
  bool failUploads = false;
  int _calls = 0;

  @override
  Future<String> uploadFile({
    required String name,
    required String filePath,
    List<String> relativeDirs = const [],
    String? existingFileId,
  }) async {
    if (offline) throw const DriveNetworkException('sin conexión');
    if (failUploads) throw const DriveQuotaException('cuota agotada');
    _calls++;
    if (_calls <= failuresBeforeSuccess) {
      throw const DriveApiException('fallo simulado');
    }
    uploadedNames.add(name);
    return 'drive-id-$_calls';
  }

  @override
  Future<DriveQuotaInfo> quota() async => quotaInfo ??
      (throw const DriveNetworkException('sin conexión'));

  @override
  Future<void> trashFile(String fileId) async {
    if (offline) throw const DriveNetworkException('sin conexión');
    trashedIds.add(fileId);
  }

  @override
  Future<void> untrashFile(String fileId) async =>
      untrashedIds.add(fileId);

  @override
  Future<void> deleteFile(String fileId) async => deletedIds.add(fileId);

  @override
  Future<List<DriveEntry>> listBackupFiles() async => backupFiles;

  @override
  Future<void> downloadFile({
    required String fileId,
    required String savePath,
  }) async {
    final file = File(savePath);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync('restaurado-$fileId');
  }
}

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

  test('escanea y encola archivos nuevos respetando exclusiones y límite',
      () async {
    File('${tempDir.path}/normal.txt').writeAsStringSync('contenido');
    File('${tempDir.path}/.oculto').writeAsStringSync('x');
    File('${tempDir.path}/doc.tmp').writeAsStringSync('x');
    File('${tempDir.path}/grande.bin').writeAsStringSync('x' * 100);

    final repo = SyncRepository(
      db,
      FakeDriveClient(),
      maxFileSizeBytes: 50,
    );
    await repo.setConfiguredFolder(tempDir.path);

    final result = await repo.scanAndEnqueue();

    expect(result.totalFiles, 2);
    expect(result.enqueued, 1);
    expect(result.skippedLarge, 1);
    expect(result.excluded, 2);

    final pending = await db.pendingItems();
    expect(pending.length, 1);
    expect(pending.first.path, '${tempDir.path}/normal.txt');
  });

  test('procesa la cola, sube a Drive y deja la cola vacía', () async {
    final file = File('${tempDir.path}/normal.txt')
      ..writeAsStringSync('contenido');
    final drive = FakeDriveClient();
    final repo = SyncRepository(db, drive);
    await repo.setConfiguredFolder(tempDir.path);

    await repo.scanAndEnqueue();
    final uploaded = await repo.processQueue();

    expect(uploaded, 1);
    expect(drive.uploadedNames, ['normal.txt']);
    expect(await db.pendingItems(), isEmpty);

    final record = await db.getUpload(file.path);
    expect(record, isNotNull);
    expect(record!.driveFileId, 'drive-id-1');
  });

  test('archivos sin cambios no se re-encolan', () async {
    final file = File('${tempDir.path}/normal.txt')
      ..writeAsStringSync('contenido');
    final repo = SyncRepository(db, FakeDriveClient());
    await repo.setConfiguredFolder(tempDir.path);

    await repo.scanAndEnqueue();
    await repo.processQueue();
    final second = await repo.scanAndEnqueue();

    expect(second.enqueued, 0);
    expect(second.unchanged, 1);
    expect(file.existsSync(), isTrue);
  });

  test('archivos modificados hace poco se aplazan', () async {
    File('${tempDir.path}/reciente.txt').writeAsStringSync('contenido');
    final repo = SyncRepository(db, FakeDriveClient());
    await repo.setConfiguredFolder(tempDir.path);

    final result = await repo.scanAndEnqueue(minAge: const Duration(minutes: 1));

    expect(result.deferred, 1);
    expect(result.enqueued, 0);
    expect(await db.pendingItems(), isEmpty);
  });

  test('tras el máximo de reintentos el archivo se salta y se registra',
      () async {
    File('${tempDir.path}/falla.txt').writeAsStringSync('contenido');
    final drive = FakeDriveClient(failuresBeforeSuccess: 99);
    final repo = SyncRepository(db, drive, maxAttempts: 2);
    await repo.setConfiguredFolder(tempDir.path);

    await repo.scanAndEnqueue();
    await repo.processQueue();
    await repo.processQueue();

    expect(await db.pendingItems(), isEmpty);
    final activity = await db.recentActivity();
    expect(
      activity.any(
        (a) => a.message.contains('saltado tras 2 intentos'),
      ),
      isTrue,
    );
  });

  test('archivos borrados localmente se retiran de la cola', () async {
    final file = File('${tempDir.path}/volatil.txt')
      ..writeAsStringSync('contenido');
    final repo = SyncRepository(db, FakeDriveClient());
    await repo.setConfiguredFolder(tempDir.path);

    await repo.scanAndEnqueue();
    await file.delete();
    await repo.processQueue();

    expect(await db.pendingItems(), isEmpty);
    expect(await db.getUpload(file.path), isNull);
  });
}
