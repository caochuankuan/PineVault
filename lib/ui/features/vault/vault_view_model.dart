import 'package:flutter/foundation.dart';

import '../../../data/repositories/vault_repository.dart';
import '../../../domain/models/vault_item.dart';

enum VaultAppState {
  initializing,
  noVault,
  creating,
  locked,
  unlocking,
  unlocked,
  saving,
}

class VaultViewModel extends ChangeNotifier {
  VaultViewModel({required VaultRepository repository})
    : _repository = repository;

  final VaultRepository _repository;
  VaultAppState _state = VaultAppState.initializing;
  String? _errorMessage;
  String _query = '';

  VaultAppState get state => _state;
  String? get errorMessage => _errorMessage;
  String get query => _query;

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

  void setQuery(String value) {
    _query = value;
    notifyListeners();
  }

  void lock() {
    _repository.lock();
    _query = '';
    _errorMessage = null;
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
