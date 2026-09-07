import 'dart:convert';

import '../../data/models/sync_state.dart';
import '../../data/repositories/vault_repository.dart';
import '../../data/repositories/webdav_repository.dart';
import '../../data/services/sync_state_service.dart';
import '../models/vault.dart';
import 'vault_merge_service.dart';

enum VaultSyncOutcome { uploaded, downloaded, merged, upToDate }

class VaultSyncResult {
  const VaultSyncResult({required this.outcome, required this.conflictCount});

  final VaultSyncOutcome outcome;
  final int conflictCount;
}

class SyncVaultUseCase {
  SyncVaultUseCase({
    required VaultRepository vaultRepository,
    required WebDavRepository webDavRepository,
    required SyncStateService stateService,
    required VaultMergeService mergeService,
  }) : _vaultRepository = vaultRepository,
       _webDavRepository = webDavRepository,
       _stateService = stateService,
       _mergeService = mergeService;

  final VaultRepository _vaultRepository;
  final WebDavRepository _webDavRepository;
  final SyncStateService _stateService;
  final VaultMergeService _mergeService;

  Future<VaultSyncResult> call() async {
    final local = _vaultRepository.vault;
    if (local == null) throw StateError('密码库尚未解锁');
    final state = await _stateService.read(local.id);
    final remoteFile = await _webDavRepository.downloadVault(local.id);

    if (remoteFile == null) {
      await _webDavRepository.ensureVaultDirectory(local.id);
      final encoded = _vaultRepository.exportEncryptedVault();
      final etag = await _webDavRepository.uploadVault(
        local.id,
        utf8.encode(encoded),
        createOnly: true,
      );
      await _stateService.write(
        local.id,
        SyncState(baseEnvelope: encoded, etag: etag),
      );
      return const VaultSyncResult(
        outcome: VaultSyncOutcome.uploaded,
        conflictCount: 0,
      );
    }

    final remoteEncoded = utf8.decode(remoteFile.bytes);
    final remote = _vaultRepository.decryptEncryptedVault(remoteEncoded);
    final base = state == null
        ? null
        : _vaultRepository.decryptEncryptedVault(state.baseEnvelope);
    final merged = _mergeService.merge(
      base: base,
      local: local,
      remote: remote,
    );
    final localChanged = !_sameVault(local, merged.vault);
    final remoteChanged = !_sameVault(remote, merged.vault);

    var etag = remoteFile.etag;
    if (remoteChanged) {
      if (etag == null || etag.isEmpty) {
        throw StateError('服务器未返回 ETag，为避免覆盖远端数据，已停止同步');
      }
      final encoded = _vaultRepository.encryptVaultForExport(merged.vault);
      etag = await _webDavRepository.uploadVault(
        local.id,
        utf8.encode(encoded),
        expectedEtag: etag,
      );
    }
    if (localChanged) await _vaultRepository.replaceVault(merged.vault);

    final currentEncoded = _vaultRepository.exportEncryptedVault();
    await _stateService.write(
      local.id,
      SyncState(baseEnvelope: currentEncoded, etag: etag),
    );
    final outcome = merged.conflictCount > 0
        ? VaultSyncOutcome.merged
        : remoteChanged
        ? VaultSyncOutcome.uploaded
        : localChanged
        ? VaultSyncOutcome.downloaded
        : VaultSyncOutcome.upToDate;
    return VaultSyncResult(
      outcome: outcome,
      conflictCount: merged.conflictCount,
    );
  }

  bool _sameVault(Vault left, Vault right) {
    final leftJson = left.toJson()..remove('updatedAt');
    final rightJson = right.toJson()..remove('updatedAt');
    return jsonEncode(leftJson) == jsonEncode(rightJson);
  }
}
