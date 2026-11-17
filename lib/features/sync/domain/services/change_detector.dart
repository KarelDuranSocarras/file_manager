enum FileChangeType { newFile, changed, unchanged }

class ChangeDetector {
  const ChangeDetector();

  FileChangeType classify({
    required int localSize,
    required int localModifiedMs,
    int? uploadedSize,
    int? uploadedModifiedMs,
  }) {
    if (uploadedSize == null || uploadedModifiedMs == null) {
      return FileChangeType.newFile;
    }
    if (localSize != uploadedSize || localModifiedMs != uploadedModifiedMs) {
      return FileChangeType.changed;
    }
    return FileChangeType.unchanged;
  }
}
