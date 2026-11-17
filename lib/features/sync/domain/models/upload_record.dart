class UploadRecord {
  const UploadRecord({
    required this.path,
    required this.size,
    required this.modifiedAtMs,
    this.driveFileId,
    this.uploadedAtMs,
  });

  final String path;
  final int size;
  final int modifiedAtMs;
  final String? driveFileId;
  final int? uploadedAtMs;

  static UploadRecord fromRow(Map<String, Object?> row) => UploadRecord(
        path: row['path'] as String,
        size: row['size'] as int,
        modifiedAtMs: row['modified_at'] as int,
        driveFileId: row['drive_file_id'] as String?,
        uploadedAtMs: row['uploaded_at'] as int?,
      );
}
