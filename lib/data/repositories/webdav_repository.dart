import '../../domain/models/webdav_configuration.dart';
import '../services/webdav_credential_store.dart';
import '../services/webdav_service.dart';

class WebDavRestoreDownload {
  const WebDavRestoreDownload({
    required this.credentials,
    required this.remoteFile,
  });

  final WebDavCredentials credentials;
  final WebDavRemoteFile remoteFile;
}

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
    await _service.ensureVaultDirectory(credentials);
    await _credentialStore.write(credentials);
  }

  Future<WebDavRestoreDownload> downloadForRestore({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    final credentials = _credentials(
      serverUrl: serverUrl,
      username: username,
      password: password,
    );
    await _service.testConnection(credentials);
    final remoteFile = await _service.downloadVault(credentials);
    if (remoteFile == null) {
      throw const WebDavException('远端没有 PineVault 密码库');
    }
    return WebDavRestoreDownload(
      credentials: credentials,
      remoteFile: remoteFile,
    );
  }

  Future<void> saveCredentials(WebDavCredentials credentials) =>
      _credentialStore.write(credentials);

  Future<void> clearConfiguration() => _credentialStore.clear();

  Future<WebDavCredentials> requireCredentials() async {
    final credentials = await _credentialStore.read();
    if (credentials == null) {
      throw StateError('尚未配置 WebDAV');
    }
    return credentials;
  }

  Future<void> ensureVaultDirectory() async {
    await _service.ensureVaultDirectory(await requireCredentials());
  }

  Future<WebDavRemoteFile?> downloadVault() async {
    return _service.downloadVault(await requireCredentials());
  }

  Future<String?> uploadVault(
    List<int> bytes, {
    String? expectedEtag,
    bool createOnly = false,
  }) async {
    return _service.uploadVault(
      await requireCredentials(),
      bytes,
      expectedEtag: expectedEtag,
      createOnly: createOnly,
    );
  }

  Future<void> ensureBackupDirectory(String vaultId) async {
    await _service.ensureBackupDirectory(await requireCredentials(), vaultId);
  }

  Future<List<WebDavBackupFile>> listBackups(String vaultId) async {
    return _service.listBackups(await requireCredentials(), vaultId);
  }

  Future<void> uploadBackup(
    String vaultId,
    String name,
    List<int> bytes,
  ) async {
    return _service.uploadBackup(
      await requireCredentials(),
      vaultId,
      name,
      bytes,
    );
  }

  Future<WebDavRemoteFile> downloadBackup(String vaultId, String name) async {
    return _service.downloadBackup(await requireCredentials(), vaultId, name);
  }

  Future<void> deleteBackup(String vaultId, String name) async {
    return _service.deleteBackup(await requireCredentials(), vaultId, name);
  }

  WebDavCredentials _credentials({
    required String serverUrl,
    required String username,
    required String password,
  }) {
    final credentials = WebDavCredentials(
      serverUri: _validateServerUri(serverUrl),
      username: username.trim(),
      password: password,
    );
    if (credentials.username.isEmpty) {
      throw const FormatException('请输入坚果云账号');
    }
    if (credentials.password.isEmpty) {
      throw const FormatException('请输入坚果云第三方应用密码');
    }
    return credentials;
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
