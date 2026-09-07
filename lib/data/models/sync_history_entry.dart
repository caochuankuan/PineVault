class SyncHistoryEntry {
  const SyncHistoryEntry({
    required this.timestamp,
    required this.trigger,
    required this.success,
    required this.message,
  });

  final DateTime timestamp;
  final String trigger;
  final bool success;
  final String message;

  factory SyncHistoryEntry.fromJson(Map<String, dynamic> json) {
    return switch (json) {
      {
        'timestamp': final String timestamp,
        'trigger': final String trigger,
        'success': final bool success,
        'message': final String message,
      } =>
        SyncHistoryEntry(
          timestamp: DateTime.parse(timestamp),
          trigger: trigger,
          success: success,
          message: message,
        ),
      _ => throw const FormatException('Invalid sync history entry.'),
    };
  }

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toUtc().toIso8601String(),
    'trigger': trigger,
    'success': success,
    'message': message,
  };
}
