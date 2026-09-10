import 'dart:convert';

import '../../domain/models/backup_entry.dart';
import '../models/sync_state.dart';
import '../services/backup_state_service.dart';
import '../services/local_backup_service.dart';
import '../services/sync_state_service.dart';
import '../services/webdav_service.dart';
import 'vault_repository.dart';
import 'webdav_repository.dart';

class BackupRestoreResult {
  const BackupRestoreResult({
    required this.webDavConfigured,
    required this.webDavSynced,
  });

  final bool webDavConfigured;
  final bool webDavSynced;
}

class BackupExport {
  const BackupExport({required this.vaultId, required this.encoded});
  final String vaultId;
  final String encoded;
}

class BackupRepository {
  BackupRepository({
    required VaultRepository vaultRepository,
    required WebDavRepository webDavRepository,
    required LocalBackupService localService,
    required BackupStateService stateService,
    required SyncStateService syncStateService,
  }) : _vaultRepository = vaultRepository,
       _webDavRepository = webDavRepository,
       _localService = localService,
       _stateService = stateService,
       _syncStateService = syncStateService;

  static const _retention = 10;
  final VaultRepository _vaultRepository;
  final WebDavRepository _webDavRepository;
  final LocalBackupService _localService;
  final BackupStateService _stateService;
  final SyncStateService _syncStateService;

  String get vaultId => _vaultRepository.currentVaultId!;
  String export() => _vaultRepository.exportEncryptedVault();
  BackupExport prepareExport() =>
      BackupExport(vaultId: vaultId, encoded: export());

  Future<BackupState> loadState() => _stateService.read(vaultId);
  Future<List<BackupEntry>> localBackups() => _localService.list(vaultId);

  Future<List<BackupEntry>> webDavBackups([String? forVaultId]) async {
    final id = forVaultId ?? vaultId;
    final files = await _webDavRepository.listBackups(id);
    return [
      for (final file in files)
        BackupEntry(
          name: file.name,
          createdAt: file.createdAt,
          size: file.size,
          location: BackupLocation.webDav,
        ),
    ];
  }

  Future<void> setAutomatic(bool enabled) async {
    final state = await loadState();
    await _stateService.write(
      vaultId,
      state.copyWith(automaticEnabled: enabled),
    );
  }

  Future<BackupState> recordManualLocalBackup(String id) async {
    final state = await _stateService.read(id);
    final updated = state.copyWith(lastLocalAt: DateTime.now().toUtc());
    await _stateService.write(id, updated);
    return updated;
  }

  Future<void> createLocal({String prefix = 'manual'}) async {
    final id = vaultId;
    await _localService.create(id, export(), prefix: prefix);
    final state = await _stateService.read(id);
    await _stateService.write(
      id,
      state.copyWith(lastLocalAt: DateTime.now().toUtc()),
    );
  }

  Future<void> createWebDav({String prefix = 'manual'}) async {
    final id = vaultId;
    await _webDavRepository.ensureBackupDirectory(id);
    final now = DateTime.now().toUtc();
    final name = prefix == 'auto'
        ? 'auto-${_dateStamp(now)}.pvlt'
        : '$prefix-${_timestamp(now)}.pvlt';
    try {
      await _webDavRepository.uploadBackup(id, name, utf8.encode(export()));
    } on WebDavException catch (error) {
      if (prefix != 'auto' || error.statusCode != 412) rethrow;
      // Another device already created today's shared automatic backup.
    }
    if (prefix == 'auto') await _trimWebDavAutomatic(id);
    final state = await _stateService.read(id);
    await _stateService.write(
      id,
      state.copyWith(lastWebDavAt: DateTime.now().toUtc()),
    );
  }

  Future<String> read(BackupEntry entry) => switch (entry.location) {
    BackupLocation.local => _localService.read(vaultId, entry.name),
    BackupLocation.webDav =>
      _webDavRepository
          .downloadBackup(vaultId, entry.name)
          .then((file) => utf8.decode(file.bytes)),
  };

  Future<void> delete(BackupEntry entry) => switch (entry.location) {
    BackupLocation.local => _localService.delete(vaultId, entry.name),
    BackupLocation.webDav => _webDavRepository.deleteBackup(
      vaultId,
      entry.name,
    ),
  };

  Future<BackupRestoreResult> restore(
    String encoded,
    String masterPassword,
  ) async {
    final id = vaultId;
    final restored = _vaultRepository.prepareRestoreExisting(
      masterPassword,
      encoded,
    );
    final current = export();
    await _localService.create(id, current, prefix: 'restore-before');

    var configured = false;
    try {
      configured = await _webDavRepository.loadConfiguration() != null;
      if (configured) {
        await _webDavRepository.ensureBackupDirectory(id);
        final name =
            'restore-before-${_timestamp(DateTime.now().toUtc())}.pvlt';
        await _webDavRepository.uploadBackup(id, name, utf8.encode(current));
      }
    } catch (_) {
      // A local restore point is sufficient to continue the restore safely.
    }

    if (!configured) {
      await _vaultRepository.restoreExisting(masterPassword, restored);
      return const BackupRestoreResult(
        webDavConfigured: false,
        webDavSynced: false,
      );
    }

    final remote = await _webDavRepository.downloadVault();
    if (remote != null && (remote.etag == null || remote.etag!.isEmpty)) {
      throw StateError('服务器未返回 ETag，已停止恢复');
    }
    final etag = await _webDavRepository.uploadVault(
      utf8.encode(restored),
      expectedEtag: remote?.etag,
      createOnly: remote == null,
    );
    await _vaultRepository.restoreExisting(masterPassword, restored);
    try {
      await _syncStateService.write(
        id,
        SyncState(baseEnvelope: restored, etag: etag),
      );
    } catch (_) {
      // The restored vault already matches WebDAV; the next sync can rebuild
      // optional baseline metadata.
    }
    return const BackupRestoreResult(
      webDavConfigured: true,
      webDavSynced: true,
    );
  }

  Future<void> _trimWebDavAutomatic(String id) async {
    final automatic =
        (await webDavBackups(id)).where((entry) => entry.isAutomatic).toList()
          ..sort((a, b) => b.name.compareTo(a.name));
    for (final entry in automatic.skip(_retention)) {
      await _webDavRepository.deleteBackup(id, entry.name);
    }
  }

  String _dateStamp(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}'
      '${value.month.toString().padLeft(2, '0')}'
      '${value.day.toString().padLeft(2, '0')}';

  String _timestamp(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}'
      '${value.month.toString().padLeft(2, '0')}'
      '${value.day.toString().padLeft(2, '0')}-'
      '${value.hour.toString().padLeft(2, '0')}'
      '${value.minute.toString().padLeft(2, '0')}'
      '${value.second.toString().padLeft(2, '0')}-'
      '${value.millisecond.toString().padLeft(3, '0')}';
}
