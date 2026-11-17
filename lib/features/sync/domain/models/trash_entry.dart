class TrashEntry {
  const TrashEntry({
    this.id,
    required this.path,
    required this.driveFileId,
    required this.name,
    required this.trashedAt,
  });

  final int? id;
  final String path;
  final String driveFileId;
  final String name;
  final DateTime trashedAt;

  static TrashEntry fromRow(Map<String, Object?> row) => TrashEntry(
        id: row['id'] as int?,
        path: row['path'] as String,
        driveFileId: row['drive_file_id'] as String,
        name: row['name'] as String,
        trashedAt: DateTime.fromMillisecondsSinceEpoch(
          row['trashed_at'] as int? ?? 0,
        ),
      );
}
