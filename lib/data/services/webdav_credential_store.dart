import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/models/webdav_configuration.dart';

abstract interface class WebDavCredentialStore {
  Future<WebDavCredentials?> read();

  Future<void> write(WebDavCredentials credentials);

  Future<void> clear();
}

class SecureWebDavCredentialStore implements WebDavCredentialStore {
  SecureWebDavCredentialStore({
    FlutterSecureStorage? storage,
    String credentialsKey = 'webdav.credentials',
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _credentialsKey = credentialsKey;

  final FlutterSecureStorage _storage;
  final String _credentialsKey;

  @override
  Future<WebDavCredentials?> read() async {
    final encoded = await _storage.read(key: _credentialsKey);
    if (encoded == null) return null;
    final value = jsonDecode(encoded);
    return switch (value) {
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
      _ => throw const FormatException('WebDAV 配置已损坏'),
    };
  }

  @override
  Future<void> write(WebDavCredentials credentials) async {
    await _storage.write(
      key: _credentialsKey,
      value: jsonEncode({
        'serverUrl': credentials.serverUri.toString(),
        'username': credentials.username,
        'password': credentials.password,
      }),
    );
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _credentialsKey);
  }
}
