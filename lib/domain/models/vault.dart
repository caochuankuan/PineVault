import 'vault_item.dart';
import 'vault_group.dart';
import 'webdav_configuration.dart';

class Vault {
  const Vault({
    required this.id,
    required this.schemaVersion,
    required this.createdAt,
    required this.updatedAt,
    required this.items,
    this.groups = const [],
    required this.tombstones,
    this.groupTombstones = const [],
    this.groupOrderUpdatedAt,
    this.webDavCredentials,
  });

  final String id;
  final int schemaVersion;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<VaultItem> items;
  final List<VaultGroup> groups;
  final List<String> tombstones;
  final List<String> groupTombstones;
  final DateTime? groupOrderUpdatedAt;
  final WebDavCredentials? webDavCredentials;

  factory Vault.fromJson(Map<String, dynamic> json) {
    final createdAt = DateTime.parse(json['createdAt'] as String);
    final updatedAt = DateTime.parse(json['updatedAt'] as String);
    final groupsValue = json['groups'] as List<dynamic>?;
    final groups = groupsValue == null || groupsValue.isEmpty
        ? [
            VaultGroup(
              id: 'default',
              name: '未分组',
              createdAt: createdAt,
              updatedAt: updatedAt,
            ),
          ]
        : groupsValue
              .map(
                (group) => VaultGroup.fromJson(group as Map<String, dynamic>),
              )
              .toList(growable: false);
    return Vault(
      id: json['id'] as String,
      schemaVersion: (json['schemaVersion'] as int? ?? 1) < 4
          ? 4
          : json['schemaVersion'] as int,
      createdAt: createdAt,
      updatedAt: updatedAt,
      groups: List.unmodifiable(groups),
      items: List.unmodifiable(
        (json['items'] as List<dynamic>).map(
          (item) => VaultItem.fromJson(item as Map<String, dynamic>),
        ),
      ),
      tombstones: List.unmodifiable(
        (json['tombstones'] as List<dynamic>).cast<String>(),
      ),
      groupTombstones: List.unmodifiable(
        (json['groupTombstones'] as List<dynamic>? ?? const []).cast<String>(),
      ),
      groupOrderUpdatedAt: json['groupOrderUpdatedAt'] == null
          ? updatedAt
          : DateTime.parse(json['groupOrderUpdatedAt'] as String),
      webDavCredentials: _webDavCredentials(json['webDav']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'schemaVersion': schemaVersion,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'items': items.map((item) => item.toJson()).toList(growable: false),
    'groups': groups.map((group) => group.toJson()).toList(growable: false),
    'tombstones': tombstones,
    'groupTombstones': groupTombstones,
    if (groupOrderUpdatedAt case final value?)
      'groupOrderUpdatedAt': value.toUtc().toIso8601String(),
    if (webDavCredentials case final credentials?)
      'webDav': {
        'serverUrl': credentials.serverUri.toString(),
        'username': credentials.username,
        'password': credentials.password,
      },
  };

  Vault copyWith({
    DateTime? updatedAt,
    List<VaultItem>? items,
    List<VaultGroup>? groups,
    List<String>? tombstones,
    List<String>? groupTombstones,
    DateTime? groupOrderUpdatedAt,
    WebDavCredentials? webDavCredentials,
    bool clearWebDavCredentials = false,
  }) {
    return Vault(
      id: id,
      schemaVersion: 4,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      items: List.unmodifiable(items ?? this.items),
      groups: List.unmodifiable(groups ?? this.groups),
      tombstones: List.unmodifiable(tombstones ?? this.tombstones),
      groupTombstones: List.unmodifiable(
        groupTombstones ?? this.groupTombstones,
      ),
      groupOrderUpdatedAt: groupOrderUpdatedAt ?? this.groupOrderUpdatedAt,
      webDavCredentials: clearWebDavCredentials
          ? null
          : webDavCredentials ?? this.webDavCredentials,
    );
  }

  static WebDavCredentials? _webDavCredentials(Object? value) {
    return switch (value) {
      null => null,
      {
        'serverUrl': final String serverUrl,
        'username': final String username,
        'password': final String password,
      } =>
        WebDavCredentials(
          serverUri: Uri.parse(serverUrl),
          username: username,
          password: password,
        ),
      _ => throw const FormatException('Invalid WebDAV configuration.'),
    };
  }
}
