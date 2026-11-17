class DriveAuthException implements Exception {
  const DriveAuthException(this.message);

  final String message;

  @override
  String toString() => 'DriveAuthException: $message';
}

class DriveNetworkException implements Exception {
  const DriveNetworkException(this.message);

  final String message;

  @override
  String toString() => 'DriveNetworkException: $message';
}

class DriveQuotaException implements Exception {
  const DriveQuotaException(this.message);

  final String message;

  @override
  String toString() => 'DriveQuotaException: $message';
}

class DriveApiException implements Exception {
  const DriveApiException(this.message);

  final String message;

  @override
  String toString() => 'DriveApiException: $message';
}

class SourceFolderMissingException implements Exception {
  const SourceFolderMissingException(this.path);

  final String path;

  @override
  String toString() => 'SourceFolderMissingException: $path';
}
