import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/models/sync_history_entry.dart';
import '../../../data/models/kdbx_transfer_data.dart';
import '../../../data/repositories/vault_repository.dart';
import '../../../data/services/kdbx_transfer_service.dart';
import '../../../data/services/sync_history_service.dart';
import '../../../domain/models/vault_item.dart';
import '../../../domain/models/vault_group.dart';
import '../../../domain/use_cases/sync_vault_use_case.dart';
import '../../../domain/use_cases/restore_vault_use_case.dart';

enum VaultAppState {
  initializing,
  noVault,
  creating,
  restoring,
  locked,
  unlocking,
  unlocked,
  saving,
  syncing,
}

enum VaultSortOrder { name, time }

class VaultViewModel extends ChangeNotifier {
  VaultViewModel({
    required VaultRepository repository,
    required KdbxTransferService kdbxTransferService,
    required SyncVaultUseCase syncVault,
    required RestoreVaultUseCase restoreVault,
    required SyncHistoryService syncHistoryService,
  }) : _repository = repository,
       _kdbxTransferService = kdbxTransferService,
       _syncVault = syncVault,
       _restoreVault = restoreVault,
       _syncHistoryService = syncHistoryService;

  final VaultRepository _repository;
  final KdbxTransferService _kdbxTransferService;
  final SyncVaultUseCase _syncVault;
  final RestoreVaultUseCase _restoreVault;
  final SyncHistoryService _syncHistoryService;
  VaultAppState _state = VaultAppState.initializing;
  String? _errorMessage;
  String? _syncMessage;
  String? _syncProgress;
  bool _webDavConflict = false;
  bool _syncRunning = false;
  List<SyncHistoryEntry> _syncHistory = const [];
  Timer? _periodicSyncTimer;
  Timer? _debouncedSyncTimer;
  String _query = '';
  bool _showPasswords = false;
  bool _showWebsites = false;
  VaultSortOrder _sortOrder = VaultSortOrder.name;
  bool _sortReversed = false;
  String _selectedGroupId = 'all';
  bool _selectionMode = false;
  final Set<String> _selectedItemIds = <String>{};

  VaultAppState get state => _state;
  String? get errorMessage => _errorMessage;
  String? get syncMessage => _syncMessage;
  String? get syncProgress => _syncProgress;
  bool get webDavConflict => _webDavConflict;
  List<SyncHistoryEntry> get syncHistory => _syncHistory;
  String get query => _query;
  bool get showPasswords => _showPasswords;
  bool get showWebsites => _showWebsites;
  VaultSortOrder get sortOrder => _sortOrder;
  bool get sortReversed => _sortReversed;
  List<VaultGroup> get groups => _repository.vault?.groups ?? const [];
  String get selectedGroupId => _selectedGroupId;
  bool get selectionMode => _selectionMode;
  Set<String> get selectedItemIds => Set.unmodifiable(_selectedItemIds);
  List<VaultItem> get selectedItems => [
    for (final item in _repository.vault?.items ?? const <VaultItem>[])
      if (_selectedItemIds.contains(item.id)) item,
  ];
  bool get busy =>
      _state == VaultAppState.saving || _state == VaultAppState.syncing;

  List<VaultItem> get items {
    final allItems = _repository.vault?.items ?? const <VaultItem>[];
    final normalizedQuery = _query.trim().toLowerCase();
    final filtered = normalizedQuery.isEmpty
        ? allItems.where(
            (item) =>
                _selectedGroupId == 'all' || item.groupId == _selectedGroupId,
          )
        : allItems.where((item) {
            final inGroup =
                _selectedGroupId == 'all' || item.groupId == _selectedGroupId;
            return inGroup &&
                (item.title.toLowerCase().contains(normalizedQuery) ||
                    item.username.toLowerCase().contains(normalizedQuery) ||
                    item.urls.any(
                      (url) => url.toLowerCase().contains(normalizedQuery),
                    ));
          });
    final result = filtered.toList(growable: false);
    result.sort((a, b) {
      if (a.favorite != b.favorite) return a.favorite ? -1 : 1;
      final comparison = _sortOrder == VaultSortOrder.time
          ? a.updatedAt.compareTo(b.updatedAt)
          : a.title.toLowerCase().compareTo(b.title.toLowerCase());
      return _sortReversed ? -comparison : comparison;
    });
    return result;
  }

  void setShowPasswords(bool value) {
    if (_showPasswords == value) return;
    _showPasswords = value;
    notifyListeners();
  }

  void setShowWebsites(bool value) {
    if (_showWebsites == value) return;
    _showWebsites = value;
    notifyListeners();
  }

  void setSortOrder(VaultSortOrder value) {
    if (_sortOrder == value) {
      _sortReversed = !_sortReversed;
    } else {
      _sortOrder = value;
      _sortReversed = false;
    }
    notifyListeners();
  }

  Future<void> initialize() async {
    _state = await _repository.hasVault()
        ? VaultAppState.locked
        : VaultAppState.noVault;
    notifyListeners();
  }

  Future<void> createVault(String masterPassword) async {
    final succeeded = await _runBusy(
      busyState: VaultAppState.creating,
      fallbackState: VaultAppState.noVault,
      operation: () => _repository.create(masterPassword),
    );
    if (succeeded) _startPeriodicSync();
  }

  Future<void> unlock(String masterPassword) async {
    final succeeded = await _runBusy(
      busyState: VaultAppState.unlocking,
      fallbackState: VaultAppState.locked,
      operation: () => _repository.unlock(masterPassword),
    );
    if (succeeded) {
      _startPeriodicSync();
      unawaited(_performSync(trigger: '解锁自动同步', quietIfUnconfigured: true));
    }
  }

  Future<String?> restore({
    required String serverUrl,
    required String username,
    required String applicationPassword,
    required String masterPassword,
  }) async {
    _state = VaultAppState.restoring;
    _errorMessage = null;
    notifyListeners();
    try {
      await _restoreVault(
        serverUrl: serverUrl,
        username: username,
        applicationPassword: applicationPassword,
        masterPassword: masterPassword,
      );
      _state = VaultAppState.unlocked;
      notifyListeners();
      _startPeriodicSync();
      unawaited(_performSync(trigger: '恢复后同步', quietIfUnconfigured: true));
      return null;
    } catch (error) {
      _state = VaultAppState.noVault;
      _errorMessage = error
          .toString()
          .replaceFirst('FormatException: ', '')
          .replaceFirst('Bad state: ', '');
      notifyListeners();
      return _errorMessage;
    }
  }

  Future<bool> saveItem({
    VaultItem? existing,
    String groupId = 'default',
    required String title,
    required String username,
    required String password,
    required String url,
    required String notes,
    List<String> tags = const [],
    required bool favorite,
  }) async {
    final succeeded = await _runBusy(
      busyState: VaultAppState.saving,
      fallbackState: VaultAppState.unlocked,
      operation: () => _repository.upsert(
        existing: existing,
        groupId: groupId,
        title: title,
        username: username,
        password: password,
        url: url,
        notes: notes,
        tags: tags,
        favorite: favorite,
      ),
    );
    if (succeeded) _scheduleSync('内容变更自动同步');
    return succeeded;
  }

  Future<bool> deleteItem(VaultItem item) async {
    final succeeded = await _runBusy(
      busyState: VaultAppState.saving,
      fallbackState: VaultAppState.unlocked,
      operation: () => _repository.delete(item),
    );
    if (succeeded) _scheduleSync('内容变更自动同步');
    return succeeded;
  }

  Future<bool> sync() => _performSync(trigger: '手动同步');

  Future<bool> _performSync({
    required String trigger,
    bool quietIfUnconfigured = false,
    bool forceUpload = false,
  }) async {
    if (_syncRunning || _repository.vault == null) return false;
    if (!await _syncVault.isConfigured()) {
      if (!quietIfUnconfigured) {
        _errorMessage = '尚未配置 WebDAV';
        notifyListeners();
      }
      return false;
    }
    _syncRunning = true;
    _state = VaultAppState.syncing;
    _errorMessage = null;
    _syncMessage = null;
    _syncProgress = '正在准备同步';
    _webDavConflict = false;
    notifyListeners();
    try {
      final result = await _syncVault(
        forceUpload: forceUpload,
        onStage: (stage) {
          _syncProgress = _stageMessage(stage);
          notifyListeners();
        },
      );
      _syncMessage = switch (result.outcome) {
        VaultSyncOutcome.uploaded => '密码库已上传',
        VaultSyncOutcome.downloaded => '已应用远端更新',
        VaultSyncOutcome.merged when result.conflictCount > 0 =>
          '同步完成，已生成 ${result.conflictCount} 个冲突副本',
        VaultSyncOutcome.merged => '同步合并完成',
        VaultSyncOutcome.upToDate => '已经是最新版本',
      };
      _webDavConflict = result.webDavConflict;
      if (result.webDavConflict) {
        _syncMessage = '同步完成；WebDAV 配置不同，已保留本机配置';
      }
      if (result.masterPasswordChanged) {
        _syncMessage = '主密码已在其他设备修改，下次解锁请输入最新主密码';
      }
      await _recordHistory(trigger, true, _syncMessage!);
      _state = VaultAppState.unlocked;
      _syncProgress = null;
      notifyListeners();
      return true;
    } catch (error) {
      _state = VaultAppState.unlocked;
      _errorMessage = error.toString().replaceFirst('Bad state: ', '');
      _syncProgress = null;
      await _recordHistory(trigger, false, _errorMessage!);
      notifyListeners();
      return false;
    } finally {
      _syncRunning = false;
    }
  }

  Future<bool> changeMasterPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final succeeded = await _runBusy(
      busyState: VaultAppState.saving,
      fallbackState: VaultAppState.unlocked,
      operation: () => _repository.changeMasterPassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      ),
    );
    if (succeeded) {
      await _performSync(
        trigger: '修改主密码后同步',
        quietIfUnconfigured: true,
        forceUpload: true,
      );
    }
    return succeeded;
  }

  Future<void> loadSyncHistory() async {
    final vault = _repository.vault;
    if (vault == null) return;
    _syncHistory = await _syncHistoryService.read(vault.id);
    notifyListeners();
  }

  void requestAutoSync() => _scheduleSync('配置变更自动同步');

  void setQuery(String value) {
    _query = value;
    notifyListeners();
  }

  void setSelectedGroup(String groupId) {
    if (_selectedGroupId == groupId) return;
    _selectedGroupId = groupId;
    notifyListeners();
  }

  void startSelectionMode() {
    _selectionMode = true;
    _selectedItemIds.clear();
    notifyListeners();
  }

  void toggleItemSelection(String id) {
    if (!_selectionMode) return;
    if (!_selectedItemIds.add(id)) _selectedItemIds.remove(id);
    notifyListeners();
  }

  void selectAllItems() {
    _selectedItemIds
      ..clear()
      ..addAll(items.map((item) => item.id));
    notifyListeners();
  }

  void clearItemSelection() {
    _selectedItemIds.clear();
    notifyListeners();
  }

  void exitSelectionMode() {
    _selectionMode = false;
    _selectedItemIds.clear();
    notifyListeners();
  }

  Future<bool> batchDelete() async {
    final ids = Set<String>.from(_selectedItemIds);
    if (ids.isEmpty) return false;
    final succeeded = await _runBusy(
      busyState: VaultAppState.saving,
      fallbackState: VaultAppState.unlocked,
      operation: () => _repository.deleteItems(ids),
    );
    if (succeeded) {
      exitSelectionMode();
      _scheduleSync('批量删除后自动同步');
    }
    return succeeded;
  }

  Future<bool> batchSetFavorite(bool favorite) async {
    final ids = Set<String>.from(_selectedItemIds);
    if (ids.isEmpty) return false;
    final succeeded = await _runBusy(
      busyState: VaultAppState.saving,
      fallbackState: VaultAppState.unlocked,
      operation: () => _repository.updateItems(ids, favorite: favorite),
    );
    if (succeeded) {
      exitSelectionMode();
      _scheduleSync('批量收藏变更后自动同步');
    }
    return succeeded;
  }

  Future<bool> batchMoveToGroup(String groupId) async {
    final ids = Set<String>.from(_selectedItemIds);
    if (ids.isEmpty) return false;
    final succeeded = await _runBusy(
      busyState: VaultAppState.saving,
      fallbackState: VaultAppState.unlocked,
      operation: () => _repository.updateItems(ids, groupId: groupId),
    );
    if (succeeded) {
      exitSelectionMode();
      _scheduleSync('批量移动分组后自动同步');
    }
    return succeeded;
  }

  Future<bool> createGroup(String name) async {
    final succeeded = await _runBusy(
      busyState: VaultAppState.saving,
      fallbackState: VaultAppState.unlocked,
      operation: () => _repository.createGroup(name),
    );
    if (succeeded) _scheduleSync('分组变更自动同步');
    return succeeded;
  }

  Future<KdbxImportPreview?> prepareKdbxImport({
    required Uint8List bytes,
    required String password,
  }) async {
    _state = VaultAppState.saving;
    _errorMessage = null;
    notifyListeners();
    try {
      final data = await _kdbxTransferService.decode(
        bytes: bytes,
        password: password,
      );
      final preview = KdbxImportPreview(
        data: data,
        duplicateIndexes: _repository.findKdbxDuplicateIndexes(data),
      );
      _state = VaultAppState.unlocked;
      notifyListeners();
      return preview;
    } catch (error) {
      _state = VaultAppState.unlocked;
      _errorMessage = _readableError(error);
      notifyListeners();
      return null;
    }
  }

  Future<KdbxImportSummary?> completeKdbxImport(
    KdbxImportPreview preview,
    Set<int> selectedIndexes,
  ) async {
    _state = VaultAppState.saving;
    _errorMessage = null;
    notifyListeners();
    try {
      final summary = await _repository.importKdbx(
        KdbxImportData(
          entries: [
            for (var index = 0; index < preview.data.entries.length; index++)
              if (selectedIndexes.contains(index)) preview.data.entries[index],
          ],
        ),
        skipDuplicates: false,
      );
      _state = VaultAppState.unlocked;
      notifyListeners();
      if (summary.itemCount > 0) _scheduleSync('KDBX 导入后自动同步');
      return summary;
    } catch (error) {
      _state = VaultAppState.unlocked;
      _errorMessage = _readableError(error);
      notifyListeners();
      return null;
    }
  }

  Future<Uint8List?> exportKdbx(String password) async {
    final vault = _repository.vault;
    if (vault == null) return null;
    _state = VaultAppState.saving;
    _errorMessage = null;
    notifyListeners();
    try {
      final bytes = await _kdbxTransferService.encode(
        vault: vault,
        password: password,
      );
      _state = VaultAppState.unlocked;
      notifyListeners();
      return bytes;
    } catch (error) {
      _state = VaultAppState.unlocked;
      _errorMessage = _readableError(error);
      notifyListeners();
      return null;
    }
  }

  void lock() {
    _periodicSyncTimer?.cancel();
    _debouncedSyncTimer?.cancel();
    _repository.lock();
    _query = '';
    _errorMessage = null;
    _syncMessage = null;
    _state = VaultAppState.locked;
    notifyListeners();
  }

  void _startPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (_state == VaultAppState.unlocked) {
        unawaited(_performSync(trigger: '定时自动同步', quietIfUnconfigured: true));
      }
    });
  }

  void _scheduleSync(
    String trigger, {
    Duration delay = const Duration(seconds: 2),
  }) {
    _debouncedSyncTimer?.cancel();
    _debouncedSyncTimer = Timer(delay, () {
      unawaited(_performSync(trigger: trigger, quietIfUnconfigured: true));
    });
  }

  Future<void> _recordHistory(
    String trigger,
    bool success,
    String message,
  ) async {
    final vault = _repository.vault;
    if (vault == null) return;
    try {
      _syncHistory = await _syncHistoryService.append(
        vault.id,
        SyncHistoryEntry(
          timestamp: DateTime.now().toUtc(),
          trigger: trigger,
          success: success,
          message: message,
        ),
      );
    } catch (_) {
      // Sync success must not be reversed by optional history persistence.
    }
  }

  String _stageMessage(VaultSyncStage stage) => switch (stage) {
    VaultSyncStage.preparing => '正在准备同步',
    VaultSyncStage.downloading => '正在下载远端密码库',
    VaultSyncStage.merging => '正在合并本地与远端更改',
    VaultSyncStage.uploading => '正在上传加密密码库',
    VaultSyncStage.saving => '正在保存合并结果',
    VaultSyncStage.retrying => '远端已更新，正在重新下载并重试',
  };

  @override
  void dispose() {
    _periodicSyncTimer?.cancel();
    _debouncedSyncTimer?.cancel();
    super.dispose();
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
      _errorMessage = _readableError(error);
      notifyListeners();
      return false;
    }
  }

  String _readableError(Object error) => error
      .toString()
      .replaceFirst('FormatException: ', '')
      .replaceFirst('Bad state: ', '')
      .replaceFirst('Exception: ', '');
}
