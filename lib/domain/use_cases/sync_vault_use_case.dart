import 'dart:convert';

import '../../data/models/sync_state.dart';
import '../../data/repositories/vault_repository.dart';
import '../../data/repositories/webdav_repository.dart';
import '../../data/services/sync_state_service.dart';
import '../../data/services/webdav_service.dart';
import '../models/vault.dart';
import 'vault_merge_service.dart';

enum VaultSyncOutcome { uploaded, downloaded, merged, upToDate }

enum VaultSyncStage {
  preparing,
  downloading,
  merging,
  uploading,
  saving,
  retrying,
}

class VaultSyncResult {
  const VaultSyncResult({
    required this.outcome,
    required this.conflictCount,
    this.webDavConflict = false,
    this.masterPasswordChanged = false,
  });

  final VaultSyncOutcome outcome;
  final int conflictCount;
  final bool webDavConflict;
  final bool masterPasswordChanged;
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

  Future<bool> isConfigured() async {
    return await _webDavRepository.loadConfiguration() != null;
  }

  Future<VaultSyncResult> call({
    bool forceUpload = false,
    void Function(VaultSyncStage stage)? onStage,
  }) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        return await _syncOnce(forceUpload: forceUpload, onStage: onStage);
      } on WebDavException catch (error) {
        if (error.statusCode != 412 || attempt == 1) rethrow;
        onStage?.call(VaultSyncStage.retrying);
      }
    }
    throw StateError('同步重试失败');
  }

  Future<VaultSyncResult> _syncOnce({
    required bool forceUpload,
    void Function(VaultSyncStage stage)? onStage,
  }) async {
    onStage?.call(VaultSyncStage.preparing);
    final local = _vaultRepository.vault;
    if (local == null) throw StateError('密码库尚未解锁');
    final state = await _stateService.read(local.id);
    final localEncodedBeforeSync = _vaultRepository.exportEncryptedVault();
    onStage?.call(VaultSyncStage.downloading);
    final remoteFile = await _webDavRepository.downloadVault();

    if (remoteFile == null) {
      await _webDavRepository.ensureVaultDirectory();
      final encoded = _vaultRepository.exportEncryptedVault();
      onStage?.call(VaultSyncStage.uploading);
      final etag = await _webDavRepository.uploadVault(
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
    onStage?.call(VaultSyncStage.merging);
    final merged = _mergeService.merge(
      base: base,
      local: local,
      remote: remote,
    );
    final localChanged = !_sameVault(local, merged.vault);
    var adoptedRemoteWrapping = false;
    if (state != null) {
      final localWrappingChanged = !_sameWrapping(
        localEncodedBeforeSync,
        state.baseEnvelope,
      );
      final remoteWrappingChanged = !_sameWrapping(
        remoteEncoded,
        state.baseEnvelope,
      );
      if (remoteWrappingChanged) {
        await _vaultRepository.adoptKeyWrapping(remoteEncoded);
        adoptedRemoteWrapping = true;
      } else if (localWrappingChanged) {
        forceUpload = true;
      }
    }
    final remoteChanged = forceUpload || !_sameVault(remote, merged.vault);

    var etag = remoteFile.etag;
    if (remoteChanged) {
      if (etag == null || etag.isEmpty) {
        throw StateError('服务器未返回 ETag，为避免覆盖远端数据，已停止同步');
      }
      onStage?.call(VaultSyncStage.uploading);
      final encoded = _vaultRepository.encryptVaultForExport(merged.vault);
      etag = await _webDavRepository.uploadVault(
        utf8.encode(encoded),
        expectedEtag: etag,
      );
    }
    if (localChanged) {
      onStage?.call(VaultSyncStage.saving);
      await _vaultRepository.replaceVault(merged.vault);
    }

    final currentEncoded = _vaultRepository.exportEncryptedVault();
    await _stateService.write(
      local.id,
      SyncState(baseEnvelope: currentEncoded, etag: etag),
    );
    final outcome = merged.conflictCount > 0
        ? VaultSyncOutcome.merged
        : remoteChanged
        ? VaultSyncOutcome.uploaded
        : localChanged || adoptedRemoteWrapping
        ? VaultSyncOutcome.downloaded
        : VaultSyncOutcome.upToDate;
    return VaultSyncResult(
      outcome: outcome,
      conflictCount: merged.conflictCount,
      webDavConflict: merged.webDavConflict,
      masterPasswordChanged: adoptedRemoteWrapping,
    );
  }

  bool _sameWrapping(String left, String right) {
    final leftEnvelope = _vaultRepository.decodeEnvelope(left);
    final rightEnvelope = _vaultRepository.decodeEnvelope(right);
    return jsonEncode({
          'kdf': leftEnvelope.kdf.toJson(),
          'wrappedKey': leftEnvelope.wrappedKey.toJson(),
        }) ==
        jsonEncode({
          'kdf': rightEnvelope.kdf.toJson(),
          'wrappedKey': rightEnvelope.wrappedKey.toJson(),
        });
  }

  bool _sameVault(Vault left, Vault right) {
    final leftJson = left.toJson()..remove('updatedAt');
    final rightJson = right.toJson()..remove('updatedAt');
    return jsonEncode(leftJson) == jsonEncode(rightJson);
  }
}
