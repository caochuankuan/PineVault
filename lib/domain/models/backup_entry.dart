enum BackupLocation { local, webDav }

class BackupEntry {
  const BackupEntry({
    required this.name,
    required this.createdAt,
    required this.size,
    required this.location,
  });

  final String name;
  final DateTime createdAt;
  final int size;
  final BackupLocation location;

  bool get isAutomatic => name.startsWith('auto-');
  bool get isRestorePoint => name.startsWith('restore-before-');
}
