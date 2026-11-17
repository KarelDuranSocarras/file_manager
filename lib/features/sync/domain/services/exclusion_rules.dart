class ExclusionRules {
  const ExclusionRules({
    this.customExtensions = const [],
    this.customNameParts = const [],
  });

  final List<String> customExtensions;
  final List<String> customNameParts;

  static const Set<String> _systemNames = {
    'thumbs.db',
    'desktop.ini',
    '.ds_store',
  };

  static const List<String> _tempExtensions = [
    '.tmp',
    '.temp',
    '.crdownload',
    '.part',
  ];

  static final RegExp _driveRoot = RegExp(r'^[A-Za-z]:$');

  bool isExcluded(String path) {
    final segments =
        path.split(RegExp(r'[/\\]')).where((s) => s.isNotEmpty).toList();
    final name = segments.isEmpty ? '' : segments.last.toLowerCase();
    final checkable = segments.where(
      (s) => s.isNotEmpty && !_driveRoot.hasMatch(s),
    );
    if (checkable.any((s) => s.startsWith('.'))) return true;
    if (name.startsWith(r'~$')) return true;
    if (_systemNames.contains(name)) return true;
    if (_tempExtensions.any(name.endsWith)) return true;
    for (final ext in customExtensions) {
      if (name.endsWith(ext.toLowerCase())) return true;
    }
    for (final part in customNameParts) {
      if (name.contains(part.toLowerCase())) return true;
    }
    return false;
  }
}
