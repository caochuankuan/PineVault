import 'vault_item.dart';
import 'webdav_configuration.dart';

class Vault {
  const Vault({
    required this.id,
    required this.schemaVersion,
    required this.createdAt,
    required this.updatedAt,
    required this.items,
    required this.tombstones,
    this.webDavCredentials,
  });

  final String id;
  final int schemaVersion;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<VaultItem> items;
  final List<String> tombstones;
  final WebDavCredentials? webDavCredentials;

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
          webDavCredentials: _webDavCredentials(json['webDav']),
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
    List<String>? tombstones,
    WebDavCredentials? webDavCredentials,
    bool clearWebDavCredentials = false,
  }) {
    return Vault(
      id: id,
      schemaVersion: schemaVersion,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      items: List.unmodifiable(items ?? this.items),
      tombstones: List.unmodifiable(tombstones ?? this.tombstones),
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
