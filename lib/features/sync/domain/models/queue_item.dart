class QueueItem {
  const QueueItem({
    required this.id,
    required this.path,
    required this.size,
    required this.modifiedAtMs,
    required this.attempts,
  });

  final int id;
  final String path;
  final int size;
  final int modifiedAtMs;
  final int attempts;

  static QueueItem fromRow(Map<String, Object?> row) => QueueItem(
        id: row['id'] as int,
        path: row['path'] as String,
        size: row['size'] as int,
        modifiedAtMs: row['modified_at'] as int,
        attempts: row['attempts'] as int? ?? 0,
      );
}
