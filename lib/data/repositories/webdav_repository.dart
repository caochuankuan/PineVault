import '../../domain/models/webdav_configuration.dart';
import '../services/webdav_credential_store.dart';
import '../services/webdav_service.dart';

class WebDavRepository {
  WebDavRepository({
    required WebDavCredentialStore credentialStore,
    required WebDavService service,
  }) : _credentialStore = credentialStore,
       _service = service;

  final WebDavCredentialStore _credentialStore;
  final WebDavService _service;

  Future<WebDavConfiguration?> loadConfiguration() async {
    final credentials = await _credentialStore.read();
    if (credentials == null) return null;
    return WebDavConfiguration(
      serverUrl: credentials.serverUri.toString(),
      username: credentials.username,
      hasPassword: credentials.password.isNotEmpty,
    );
  }

  Future<void> testAndSave({
    required String serverUrl,
    required String username,
    required String password,
    required String vaultId,
  }) async {
    final current = await _credentialStore.read();
    final normalizedPassword = password.isEmpty
        ? current?.password ?? ''
        : password;
    final credentials = WebDavCredentials(
      serverUri: _validateServerUri(serverUrl),
      username: username.trim(),
      password: normalizedPassword,
    );
    if (credentials.username.isEmpty) {
      throw const FormatException('请输入坚果云账号');
    }
    if (credentials.password.isEmpty) {
      throw const FormatException('请输入坚果云第三方应用密码');
    }

    await _service.testConnection(credentials);
    await _service.ensureVaultDirectory(credentials, vaultId);
    await _credentialStore.write(credentials);
  }

  Future<void> clearConfiguration() => _credentialStore.clear();

  Future<WebDavCredentials> requireCredentials() async {
    final credentials = await _credentialStore.read();
    if (credentials == null) {
      throw StateError('尚未配置 WebDAV');
    }
    return credentials;
  }

  Future<void> ensureVaultDirectory(String vaultId) async {
    await _service.ensureVaultDirectory(await requireCredentials(), vaultId);
  }

  Future<WebDavRemoteFile?> downloadVault(String vaultId) async {
    return _service.downloadVault(await requireCredentials(), vaultId);
  }

  Future<String?> uploadVault(
    String vaultId,
    List<int> bytes, {
    String? expectedEtag,
    bool createOnly = false,
  }) async {
    return _service.uploadVault(
      await requireCredentials(),
      vaultId,
      bytes,
      expectedEtag: expectedEtag,
      createOnly: createOnly,
    );
  }

  Uri _validateServerUri(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw const FormatException('WebDAV 地址必须是有效的 HTTPS 地址');
    }
    if (uri.hasQuery || uri.hasFragment || uri.userInfo.isNotEmpty) {
      throw const FormatException('WebDAV 地址不能包含账号、查询参数或片段');
    }
    final path = uri.path.endsWith('/') ? uri.path : '${uri.path}/';
    return uri.replace(path: path);
  }
}
