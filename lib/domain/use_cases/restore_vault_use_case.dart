import 'dart:convert';

import '../../data/models/sync_state.dart';
import '../../data/repositories/vault_repository.dart';
import '../../data/repositories/webdav_repository.dart';
import '../../data/services/sync_state_service.dart';

class RestoreVaultUseCase {
  RestoreVaultUseCase({
    required VaultRepository vaultRepository,
    required WebDavRepository webDavRepository,
    required SyncStateService stateService,
  }) : _vaultRepository = vaultRepository,
       _webDavRepository = webDavRepository,
       _stateService = stateService;

  final VaultRepository _vaultRepository;
  final WebDavRepository _webDavRepository;
  final SyncStateService _stateService;

  Future<void> call({
    required String serverUrl,
    required String username,
    required String applicationPassword,
    required String masterPassword,
  }) async {
    final download = await _webDavRepository.downloadForRestore(
      serverUrl: serverUrl,
      username: username,
      password: applicationPassword,
    );
    final encoded = utf8.decode(download.remoteFile.bytes);
    final vaultId = _vaultRepository.validateRestore(masterPassword, encoded);

    await _stateService.write(
      vaultId,
      SyncState(baseEnvelope: encoded, etag: download.remoteFile.etag),
    );
    await _webDavRepository.saveCredentials(download.credentials);
    await _vaultRepository.restore(masterPassword, encoded);
  }
}
