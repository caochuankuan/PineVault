import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pine_vault/data/repositories/backup_repository.dart';
import 'package:pine_vault/data/services/backup_state_service.dart';
import 'package:pine_vault/domain/models/backup_entry.dart';
import 'package:pine_vault/ui/features/backup/backup_view_model.dart';
import 'package:pine_vault/ui/features/vault/vault_view_model.dart';

void main() {
  test(
    'automatic backup creates due local and WebDAV snapshots exclusively',
    () async {
      final repository = _FakeBackupRepository();
      final vaultViewModel = _FakeVaultViewModel();
      final viewModel = BackupViewModel(
        repository: repository,
        vaultViewModel: vaultViewModel,
      );

      expect(await viewModel.checkAutomatic(), isTrue);

      expect(repository.localCreates, 1);
      expect(repository.webDavCreates, 1);
      expect(vaultViewModel.exclusiveCalls, 2);
      expect(viewModel.message, contains('本地自动备份成功'));
      expect(viewModel.message, contains('WebDAV 自动备份成功'));
    },
  );

  test('automatic backup waits while the vault is syncing', () async {
    final repository = _FakeBackupRepository();
    final vaultViewModel = _FakeVaultViewModel()
      ..currentState = VaultAppState.syncing;
    final viewModel = BackupViewModel(
      repository: repository,
      vaultViewModel: vaultViewModel,
    );

    expect(await viewModel.checkAutomatic(), isFalse);
    expect(repository.localCreates, 0);
    expect(repository.webDavCreates, 0);
    expect(vaultViewModel.exclusiveCalls, 0);
  });

  test('recording a manual local backup does not refresh WebDAV', () async {
    final repository = _FakeBackupRepository();
    final viewModel = BackupViewModel(
      repository: repository,
      vaultViewModel: _FakeVaultViewModel(),
    );

    await viewModel.recordManualLocalBackup('vault-id');

    expect(repository.webDavReads, 0);
    expect(viewModel.state.lastLocalAt, DateTime.utc(2026, 9, 10));
  });
}

class _FakeBackupRepository implements BackupRepository {
  int localCreates = 0;
  int webDavCreates = 0;
  int webDavReads = 0;

  @override
  Future<BackupState> loadState() async => const BackupState();

  @override
  Future<List<BackupEntry>> localBackups() async => const [];

  @override
  Future<List<BackupEntry>> webDavBackups([String? forVaultId]) async {
    webDavReads++;
    return const [];
  }

  @override
  Future<BackupState> recordManualLocalBackup(String id) async =>
      BackupState(lastLocalAt: DateTime.utc(2026, 9, 10));

  @override
  Future<void> createLocal({String prefix = 'manual'}) async {
    expect(prefix, 'auto');
    localCreates++;
  }

  @override
  Future<void> createWebDav({String prefix = 'manual'}) async {
    expect(prefix, 'auto');
    webDavCreates++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeVaultViewModel extends ChangeNotifier implements VaultViewModel {
  VaultAppState currentState = VaultAppState.unlocked;
  int exclusiveCalls = 0;

  @override
  VaultAppState get state => currentState;

  @override
  Future<T> runExclusiveVaultOperation<T>(
    Future<T> Function() operation,
  ) async {
    if (currentState != VaultAppState.unlocked) {
      throw StateError('busy');
    }
    exclusiveCalls++;
    currentState = VaultAppState.saving;
    try {
      return await operation();
    } finally {
      currentState = VaultAppState.unlocked;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
