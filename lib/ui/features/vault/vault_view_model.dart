import 'package:flutter/foundation.dart';

import '../../../data/repositories/vault_repository.dart';
import '../../../domain/models/vault_item.dart';
import '../../../domain/use_cases/sync_vault_use_case.dart';

enum VaultAppState {
  initializing,
  noVault,
  creating,
  locked,
  unlocking,
  unlocked,
  saving,
  syncing,
}

class VaultViewModel extends ChangeNotifier {
  VaultViewModel({
    required VaultRepository repository,
    required SyncVaultUseCase syncVault,
  }) : _repository = repository,
       _syncVault = syncVault;

  final VaultRepository _repository;
  final SyncVaultUseCase _syncVault;
  VaultAppState _state = VaultAppState.initializing;
  String? _errorMessage;
  String? _syncMessage;
  String _query = '';

  VaultAppState get state => _state;
  String? get errorMessage => _errorMessage;
  String? get syncMessage => _syncMessage;
  String get query => _query;
  String? get vaultId => _repository.vault?.id;
  bool get busy =>
      _state == VaultAppState.saving || _state == VaultAppState.syncing;

  List<VaultItem> get items {
    final allItems = _repository.vault?.items ?? const <VaultItem>[];
    final normalizedQuery = _query.trim().toLowerCase();
    final filtered = normalizedQuery.isEmpty
        ? allItems
        : allItems.where((item) {
            return item.title.toLowerCase().contains(normalizedQuery) ||
                item.username.toLowerCase().contains(normalizedQuery) ||
                item.urls.any(
                  (url) => url.toLowerCase().contains(normalizedQuery),
                );
          });
    final result = filtered.toList(growable: false);
    result.sort((a, b) {
      if (a.favorite != b.favorite) return a.favorite ? -1 : 1;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return result;
  }

  Future<void> initialize() async {
    _state = await _repository.hasVault()
        ? VaultAppState.locked
        : VaultAppState.noVault;
    notifyListeners();
  }

  Future<void> createVault(String masterPassword) => _runBusy(
    busyState: VaultAppState.creating,
    fallbackState: VaultAppState.noVault,
    operation: () => _repository.create(masterPassword),
  );

  Future<void> unlock(String masterPassword) => _runBusy(
    busyState: VaultAppState.unlocking,
    fallbackState: VaultAppState.locked,
    operation: () => _repository.unlock(masterPassword),
  );

  Future<bool> saveItem({
    VaultItem? existing,
    required String title,
    required String username,
    required String password,
    required String url,
    required String notes,
    required bool favorite,
  }) => _runBusy(
    busyState: VaultAppState.saving,
    fallbackState: VaultAppState.unlocked,
    operation: () => _repository.upsert(
      existing: existing,
      title: title,
      username: username,
      password: password,
      url: url,
      notes: notes,
      favorite: favorite,
    ),
  );

  Future<bool> deleteItem(VaultItem item) => _runBusy(
    busyState: VaultAppState.saving,
    fallbackState: VaultAppState.unlocked,
    operation: () => _repository.delete(item),
  );

  Future<bool> sync() async {
    _state = VaultAppState.syncing;
    _errorMessage = null;
    _syncMessage = null;
    notifyListeners();
    try {
      final result = await _syncVault();
      _syncMessage = switch (result.outcome) {
        VaultSyncOutcome.uploaded => '密码库已上传',
        VaultSyncOutcome.downloaded => '已应用远端更新',
        VaultSyncOutcome.merged when result.conflictCount > 0 =>
          '同步完成，已生成 ${result.conflictCount} 个冲突副本',
        VaultSyncOutcome.merged => '同步合并完成',
        VaultSyncOutcome.upToDate => '已经是最新版本',
      };
      _state = VaultAppState.unlocked;
      notifyListeners();
      return true;
    } catch (error) {
      _state = VaultAppState.unlocked;
      _errorMessage = error.toString().replaceFirst('Bad state: ', '');
      notifyListeners();
      return false;
    }
  }

  void setQuery(String value) {
    _query = value;
    notifyListeners();
  }

  void lock() {
    _repository.lock();
    _query = '';
    _errorMessage = null;
    _syncMessage = null;
    _state = VaultAppState.locked;
    notifyListeners();
  }

  Future<bool> _runBusy({
    required VaultAppState busyState,
    required VaultAppState fallbackState,
    required Future<void> Function() operation,
  }) async {
    _state = busyState;
    _errorMessage = null;
    notifyListeners();
    try {
      await operation();
      _state = VaultAppState.unlocked;
      notifyListeners();
      return true;
    } catch (error) {
      _state = fallbackState;
      _errorMessage = error.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }
}
