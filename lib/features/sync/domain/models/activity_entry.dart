enum ActivityType { info, warning, error }

class ActivityEntry {
  const ActivityEntry({
    this.id,
    required this.type,
    required this.message,
    this.path,
    required this.createdAt,
  });

  final int? id;
  final ActivityType type;
  final String message;
  final String? path;
  final DateTime createdAt;

  Map<String, Object?> toRow() => {
        'type': type.name,
        'message': message,
        'path': path,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  static ActivityEntry fromRow(Map<String, Object?> row) => ActivityEntry(
        id: row['id'] as int?,
        type: ActivityType.values.firstWhere(
          (t) => t.name == row['type'],
          orElse: () => ActivityType.info,
        ),
        message: row['message'] as String? ?? '',
        path: row['path'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          row['created_at'] as int? ?? 0,
        ),
      );
}
