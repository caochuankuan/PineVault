class SyncState {
  const SyncState({required this.baseEnvelope, required this.etag});

  final String baseEnvelope;
  final String? etag;

  factory SyncState.fromJson(Map<String, dynamic> json) {
    return switch (json) {
      {'baseEnvelope': final String baseEnvelope, 'etag': final String? etag} =>
        SyncState(baseEnvelope: baseEnvelope, etag: etag),
      _ => throw const FormatException('Invalid sync state.'),
    };
  }

  Map<String, dynamic> toJson() => {'baseEnvelope': baseEnvelope, 'etag': etag};
}
