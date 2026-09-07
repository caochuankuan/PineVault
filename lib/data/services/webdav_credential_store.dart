import '../../domain/models/webdav_configuration.dart';
import '../repositories/vault_repository.dart';

abstract interface class WebDavCredentialStore {
  Future<WebDavCredentials?> read();

  Future<void> write(WebDavCredentials credentials);

  Future<void> clear();
}

class VaultWebDavCredentialStore implements WebDavCredentialStore {
  VaultWebDavCredentialStore(this._vaultRepository);

  final VaultRepository _vaultRepository;

  @override
  Future<WebDavCredentials?> read() async {
    return _vaultRepository.vault?.webDavCredentials;
  }

  @override
  Future<void> write(WebDavCredentials credentials) {
    return _vaultRepository.saveWebDavCredentials(credentials);
  }

  @override
  Future<void> clear() => _vaultRepository.clearWebDavCredentials();
}
