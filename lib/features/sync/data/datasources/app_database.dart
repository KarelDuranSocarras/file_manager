import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../domain/models/activity_entry.dart';
import '../../domain/models/queue_item.dart';
import '../../domain/models/trash_entry.dart';
import '../../domain/models/upload_record.dart';

class AppDatabase {
  AppDatabase._(this._db);

  final Database _db;

  static Future<AppDatabase> open(String path) async {
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
    return AppDatabase._(db);
  }

  static Future<void> _onCreate(Database db, int version) async {
    await _createConfig(db);
    await _createUploads(db);
    await _createQueue(db);
    await _createActivity(db);
    await _createTrash(db);
  }

  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await _createTrash(db);
    }
  }

  static Future<void> _createConfig(Database db) => db.execute(
        'CREATE TABLE IF NOT EXISTS config '
        '(key TEXT PRIMARY KEY, value TEXT NOT NULL)',
      );

  static Future<void> _createUploads(Database db) => db.execute(
        'CREATE TABLE IF NOT EXISTS uploads '
        '(path TEXT PRIMARY KEY, size INTEGER NOT NULL, '
        'modified_at INTEGER NOT NULL, drive_file_id TEXT, '
        'uploaded_at INTEGER)',
      );

  static Future<void> _createQueue(Database db) => db.execute(
        'CREATE TABLE IF NOT EXISTS queue '
        '(id INTEGER PRIMARY KEY AUTOINCREMENT, path TEXT NOT NULL UNIQUE, '
        'size INTEGER NOT NULL, modified_at INTEGER NOT NULL, '
        'attempts INTEGER NOT NULL DEFAULT 0)',
      );

  static Future<void> _createActivity(Database db) => db.execute(
        'CREATE TABLE IF NOT EXISTS activity '
        '(id INTEGER PRIMARY KEY AUTOINCREMENT, type TEXT NOT NULL, '
        'message TEXT NOT NULL, path TEXT, created_at INTEGER NOT NULL)',
      );

  static Future<void> _createTrash(Database db) => db.execute(
        'CREATE TABLE IF NOT EXISTS trash '
        '(id INTEGER PRIMARY KEY AUTOINCREMENT, path TEXT NOT NULL, '
        'drive_file_id TEXT NOT NULL UNIQUE, name TEXT NOT NULL, '
        'trashed_at INTEGER NOT NULL)',
      );

  Future<String?> getConfig(String key) async {
    final rows = await _db.query(
      'config',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> setConfig(String key, String value) => _db.insert(
        'config',
        {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<void> removeConfig(String key) =>
      _db.delete('config', where: 'key = ?', whereArgs: [key]);

  Future<UploadRecord?> getUpload(String path) async {
    final rows = await _db.query(
      'uploads',
      where: 'path = ?',
      whereArgs: [path],
      limit: 1,
    );
    return rows.isEmpty ? null : UploadRecord.fromRow(rows.first);
  }

  Future<List<UploadRecord>> allUploads() async {
    final rows = await _db.query('uploads');
    return rows.map(UploadRecord.fromRow).toList();
  }

  Future<int> uploadCount() async {
    final res = await _db.rawQuery('SELECT COUNT(*) AS n FROM uploads');
    return (res.first['n'] as int?) ?? 0;
  }

  Future<void> upsertUpload(UploadRecord record) => _db.insert(
        'uploads',
        {
          'path': record.path,
          'size': record.size,
          'modified_at': record.modifiedAtMs,
          'drive_file_id': record.driveFileId,
          'uploaded_at': record.uploadedAtMs,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<void> deleteUpload(String path) =>
      _db.delete('uploads', where: 'path = ?', whereArgs: [path]);

  Future<void> enqueue(String path, int size, int modifiedAtMs) async {
    final existing = await _db.query(
      'queue',
      where: 'path = ?',
      whereArgs: [path],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      await _db.update(
        'queue',
        {'size': size, 'modified_at': modifiedAtMs},
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
      return;
    }
    await _db.insert('queue', {
      'path': path,
      'size': size,
      'modified_at': modifiedAtMs,
    });
  }

  Future<List<QueueItem>> pendingItems({int limit = 5}) async {
    final rows = await _db.query('queue', orderBy: 'id ASC', limit: limit);
    return rows.map(QueueItem.fromRow).toList();
  }

  Future<void> removeQueueItem(int id) =>
      _db.delete('queue', where: 'id = ?', whereArgs: [id]);

  Future<void> clearQueue() => _db.delete('queue');

  Future<void> incrementAttempts(int id) => _db.rawUpdate(
        'UPDATE queue SET attempts = attempts + 1 WHERE id = ?',
        [id],
      );

  Future<void> markUploaded({
    required QueueItem item,
    required String driveFileId,
  }) async {
    await _db.transaction((txn) async {
      await txn.insert(
        'uploads',
        {
          'path': item.path,
          'size': item.size,
          'modified_at': item.modifiedAtMs,
          'drive_file_id': driveFileId,
          'uploaded_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.delete('queue', where: 'id = ?', whereArgs: [item.id]);
    });
  }

  Future<void> addTrashEntry({
    required String path,
    required String driveFileId,
    required String name,
    DateTime? trashedAt,
  }) =>
      _db.insert('trash', {
        'path': path,
        'drive_file_id': driveFileId,
        'name': name,
        'trashed_at':
            (trashedAt ?? DateTime.now()).millisecondsSinceEpoch,
      });

  Future<List<TrashEntry>> trashEntries() async {
    final rows = await _db.query('trash', orderBy: 'trashed_at DESC');
    return rows.map(TrashEntry.fromRow).toList();
  }

  Future<List<TrashEntry>> expiredTrash(DateTime cutoff) async {
    final rows = await _db.query(
      'trash',
      where: 'trashed_at < ?',
      whereArgs: [cutoff.millisecondsSinceEpoch],
    );
    return rows.map(TrashEntry.fromRow).toList();
  }

  Future<void> removeTrashEntry(int id) =>
      _db.delete('trash', where: 'id = ?', whereArgs: [id]);

  Future<void> logActivity(ActivityEntry entry) =>
      _db.insert('activity', entry.toRow());

  Future<List<ActivityEntry>> recentActivity({int limit = 100}) async {
    final rows = await _db.query('activity', orderBy: 'id DESC', limit: limit);
    return rows.map(ActivityEntry.fromRow).toList();
  }

  Future<void> close() => _db.close();
}
