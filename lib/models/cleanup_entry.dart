class CleanupEntry {
  CleanupEntry({
    required this.path,
    required this.reason,
    required this.isDirectory,
    this.selected = true,
  });

  final String path;
  final String reason;
  final bool isDirectory;
  bool selected;
}
