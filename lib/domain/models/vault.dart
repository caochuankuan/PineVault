import 'vault_item.dart';

class Vault {
  const Vault({
    required this.id,
    required this.schemaVersion,
    required this.createdAt,
    required this.updatedAt,
    required this.items,
    required this.tombstones,
  });

  final String id;
  final int schemaVersion;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<VaultItem> items;
  final List<String> tombstones;

  factory Vault.fromJson(Map<String, dynamic> json) {
    return switch (json) {
      {
        'id': final String id,
        'schemaVersion': final int schemaVersion,
        'createdAt': final String createdAt,
        'updatedAt': final String updatedAt,
        'items': final List<dynamic> items,
        'tombstones': final List<dynamic> tombstones,
      } =>
        Vault(
          id: id,
          schemaVersion: schemaVersion,
          createdAt: DateTime.parse(createdAt),
          updatedAt: DateTime.parse(updatedAt),
          items: List.unmodifiable(
            items.map(
              (item) => VaultItem.fromJson(item as Map<String, dynamic>),
            ),
          ),
          tombstones: List.unmodifiable(tombstones.cast<String>()),
        ),
      _ => throw const FormatException('Invalid vault.'),
    };
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'schemaVersion': schemaVersion,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'items': items.map((item) => item.toJson()).toList(growable: false),
    'tombstones': tombstones,
  };

  Vault copyWith({
    DateTime? updatedAt,
    List<VaultItem>? items,
    List<String>? tombstones,
  }) {
    return Vault(
      id: id,
      schemaVersion: schemaVersion,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      items: List.unmodifiable(items ?? this.items),
      tombstones: List.unmodifiable(tombstones ?? this.tombstones),
    );
  }
}
