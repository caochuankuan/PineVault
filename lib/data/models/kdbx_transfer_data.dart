class KdbxImportData {
  const KdbxImportData({required this.entries});

  final List<KdbxImportEntry> entries;
}

class KdbxImportEntry {
  const KdbxImportEntry({
    required this.groupName,
    required this.title,
    required this.username,
    required this.password,
    required this.url,
    required this.notes,
    this.tags = const [],
    required this.favorite,
    required this.createdAt,
    required this.updatedAt,
  });

  final String groupName;
  final String title;
  final String username;
  final String password;
  final String url;
  final String notes;
  final List<String> tags;
  final bool favorite;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class KdbxImportSummary {
  const KdbxImportSummary({
    required this.itemCount,
    required this.createdGroupCount,
    required this.skippedDuplicateCount,
  });

  final int itemCount;
  final int createdGroupCount;
  final int skippedDuplicateCount;
}

class KdbxImportPreview {
  const KdbxImportPreview({required this.data, required this.duplicateIndexes});

  final KdbxImportData data;
  final Set<int> duplicateIndexes;

  int get duplicateCount => duplicateIndexes.length;
}
