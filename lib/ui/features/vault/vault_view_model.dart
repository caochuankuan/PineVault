import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/models/sync_history_entry.dart';
import '../../../data/models/kdbx_transfer_data.dart';
import '../../../data/repositories/vault_repository.dart';
import '../../../data/services/kdbx_transfer_service.dart';
import '../../../data/services/device_unlock_service.dart';
import '../../../data/services/sync_history_service.dart';
import '../../../domain/models/vault_item.dart';
import '../../../domain/models/totp_config.dart';
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
  static const String totpGroupId = 'system:totp';

  VaultViewModel({
    required VaultRepository repository,
    required DeviceUnlockService deviceUnlockService,
    required KdbxTransferService kdbxTransferService,
    required SyncVaultUseCase syncVault,
    required RestoreVaultUseCase restoreVault,
    required SyncHistoryService syncHistoryService,
  }) : _repository = repository,
       _deviceUnlockService = deviceUnlockService,
       _kdbxTransferService = kdbxTransferService,
       _syncVault = syncVault,
       _restoreVault = restoreVault,
       _syncHistoryService = syncHistoryService;

  final VaultRepository _repository;
  final DeviceUnlockService _deviceUnlockService;
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
  bool _showTotp = false;
  VaultSortOrder _sortOrder = VaultSortOrder.name;
  bool _sortReversed = false;
  String _selectedGroupId = 'all';
  bool _selectionMode = false;
  final Set<String> _selectedItemIds = <String>{};
  bool _deviceUnlockSupported = false;
  bool _deviceUnlockEnabled = false;
  bool _deviceUnlockBusy = false;
  bool _automaticDeviceUnlock = true;
  int _sessionVersion = 0;

  VaultAppState get state => _state;
  String? get errorMessage => _errorMessage;
  String? get syncMessage => _syncMessage;
  String? get syncProgress => _syncProgress;
  bool get webDavConflict => _webDavConflict;
  List<SyncHistoryEntry> get syncHistory => _syncHistory;
  String get query => _query;
  bool get showPasswords => _showPasswords;
  bool get showWebsites => _showWebsites;
  bool get showTotp => _showTotp;
  bool get automaticDeviceUnlock => _automaticDeviceUnlock;
  bool get shouldShowTotp => _showTotp || _selectedGroupId == totpGroupId;
  VaultSortOrder get sortOrder => _sortOrder;
  bool get sortReversed => _sortReversed;
  List<VaultGroup> get groups => _repository.vault?.groups ?? const [];
  int itemCountForGroup(String groupId) =>
      _repository.vault?.items.where((item) {
        if (groupId == totpGroupId) return item.totp != null;
        return item.groupId == groupId;
      }).length ??
      0;
  String get selectedGroupId => _selectedGroupId;
  bool get selectionMode => _selectionMode;
  bool get deviceUnlockSupported => _deviceUnlockSupported;
  bool get deviceUnlockEnabled => _deviceUnlockEnabled;
  bool get deviceUnlockBusy => _deviceUnlockBusy;
  Set<String> get selectedItemIds => Set.unmodifiable(_selectedItemIds);
  List<VaultItem> get selectedItems => [
    for (final item in _repository.vault?.items ?? const <VaultItem>[])
      if (_selectedItemIds.contains(item.id)) item,
  ];
  bool get busy =>
      _state == VaultAppState.saving ||
      _state == VaultAppState.syncing ||
      _deviceUnlockBusy;

  List<VaultItem> get items {
    final allItems = _repository.vault?.items ?? const <VaultItem>[];
    final normalizedQuery = _query.trim().toLowerCase();
    final filtered = normalizedQuery.isEmpty
        ? allItems.where(_isInSelectedGroup)
        : allItems.where((item) {
            return _isInSelectedGroup(item) &&
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

  bool _isInSelectedGroup(VaultItem item) {
    if (_selectedGroupId == 'all') return true;
    if (_selectedGroupId == totpGroupId) return item.totp != null;
    return item.groupId == _selectedGroupId;
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

  void setShowTotp(bool value) {
    if (_showTotp == value) return;
    _showTotp = value;
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
    final hasVault = await _repository.hasVault();
    _state = hasVault ? VaultAppState.locked : VaultAppState.noVault;
    _deviceUnlockSupported = await _deviceUnlockService.isAvailable();
    if (hasVault) {
      _deviceUnlockEnabled =
          _deviceUnlockSupported &&
          await _deviceUnlockService.isEnabledFor(
            await _repository.storedVaultId(),
          );
    }
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
      _automaticDeviceUnlock = true;
      _startPeriodicSync();
      unawaited(_performSync(trigger: '解锁自动同步', quietIfUnconfigured: true));
    }
  }

  Future<void> unlockWithDevice() async {
    if (_state != VaultAppState.locked || !_deviceUnlockEnabled) return;
    _state = VaultAppState.unlocking;
    _errorMessage = null;
    notifyListeners();
    Uint8List? rawKey;
    try {
      final vaultId = await _repository.storedVaultId();
      rawKey = await _deviceUnlockService.readVaultKey(
        vaultId,
        requireFreshAuthentication: true,
      );
      await _repository.unlockWithDeviceKey(rawKey);
      _state = VaultAppState.unlocked;
      _automaticDeviceUnlock = true;
      _startPeriodicSync();
      notifyListeners();
      unawaited(_performSync(trigger: '解锁自动同步', quietIfUnconfigured: true));
    } catch (error) {
      _state = VaultAppState.locked;
      _errorMessage = _readableError(error);
      notifyListeners();
    } finally {
      rawKey?.fillRange(0, rawKey.length, 0);
    }
  }

  Future<bool> enableDeviceUnlock(String masterPassword) async {
    final vaultId = _repository.currentVaultId;
    if (vaultId == null || _deviceUnlockBusy) return false;
    _deviceUnlockBusy = true;
    _errorMessage = null;
    notifyListeners();
    Uint8List? rawKey;
    try {
      rawKey = _repository.exportDeviceUnlockKey(masterPassword);
      await _deviceUnlockService.enable(vaultId: vaultId, vaultKey: rawKey);
      _deviceUnlockEnabled = true;
      return true;
    } catch (error) {
      _errorMessage = _readableError(error);
      return false;
    } finally {
      rawKey?.fillRange(0, rawKey.length, 0);
      _deviceUnlockBusy = false;
      notifyListeners();
    }
  }

  Future<bool> disableDeviceUnlock() async {
    if (_deviceUnlockBusy) return false;
    _deviceUnlockBusy = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _deviceUnlockService.disable();
      _deviceUnlockEnabled = false;
      return true;
    } catch (error) {
      _errorMessage = _readableError(error);
      return false;
    } finally {
      _deviceUnlockBusy = false;
      notifyListeners();
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
    TotpConfig? totp,
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
        totp: totp,
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

  Future<T> runExclusiveVaultOperation<T>(
    Future<T> Function() operation,
  ) async {
    if (_state != VaultAppState.unlocked) {
      throw StateError('密码库正在执行其他操作');
    }
    final sessionVersion = _sessionVersion;
    final hadPendingSync = _debouncedSyncTimer?.isActive ?? false;
    _debouncedSyncTimer?.cancel();
    _state = VaultAppState.saving;
    notifyListeners();
    try {
      final result = await operation();
      if (!_isSessionActive(sessionVersion)) {
        throw StateError('密码库已经锁定');
      }
      return result;
    } finally {
      if (_isSessionActive(sessionVersion)) {
        _state = VaultAppState.unlocked;
        notifyListeners();
        if (hadPendingSync) _scheduleSync('延迟自动同步');
      }
    }
  }

  Future<bool> _performSync({
    required String trigger,
    bool quietIfUnconfigured = false,
    bool forceUpload = false,
  }) async {
    final sessionVersion = _sessionVersion;
    if (_state != VaultAppState.unlocked ||
        _syncRunning ||
        _repository.vault == null) {
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
      if (!await _syncVault.isConfigured()) {
        if (!_isSessionActive(sessionVersion)) return false;
        _state = VaultAppState.unlocked;
        _syncProgress = null;
        if (!quietIfUnconfigured) _errorMessage = '尚未配置 WebDAV';
        notifyListeners();
        return false;
      }
      if (!_isSessionActive(sessionVersion)) return false;
      final result = await _syncVault(
        forceUpload: forceUpload,
        onStage: (stage) {
          if (sessionVersion != _sessionVersion) return;
          _syncProgress = _stageMessage(stage);
          notifyListeners();
        },
      );
      if (sessionVersion != _sessionVersion || _repository.vault == null) {
        return false;
      }
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
      if (sessionVersion != _sessionVersion || _repository.vault == null) {
        return false;
      }
      _state = VaultAppState.unlocked;
      _syncProgress = null;
      notifyListeners();
      return true;
    } catch (error) {
      if (sessionVersion != _sessionVersion || _repository.vault == null) {
        return false;
      }
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

  Future<bool> renameGroup(String groupId, String name) async {
    final succeeded = await _runBusy(
      busyState: VaultAppState.saving,
      fallbackState: VaultAppState.unlocked,
      operation: () => _repository.renameGroup(groupId, name),
    );
    if (succeeded) _scheduleSync('分组重命名后自动同步');
    return succeeded;
  }

  Future<bool> deleteGroup(String groupId) async {
    final succeeded = await _runBusy(
      busyState: VaultAppState.saving,
      fallbackState: VaultAppState.unlocked,
      operation: () => _repository.deleteGroup(groupId),
    );
    if (succeeded) {
      if (_selectedGroupId == groupId) _selectedGroupId = 'all';
      _scheduleSync('分组删除后自动同步');
    }
    return succeeded;
  }

  Future<bool> reorderGroups(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex -= 1;
    final succeeded = await _runBusy(
      busyState: VaultAppState.saving,
      fallbackState: VaultAppState.unlocked,
      operation: () => _repository.reorderGroups(oldIndex, newIndex),
    );
    if (succeeded) _scheduleSync('分组排序后自动同步');
    return succeeded;
  }

  Future<KdbxImportPreview?> prepareKdbxImport({
    required Uint8List bytes,
    required String password,
  }) async {
    final sessionVersion = _sessionVersion;
    _state = VaultAppState.saving;
    _errorMessage = null;
    notifyListeners();
    try {
      final data = await _kdbxTransferService.decode(
        bytes: bytes,
        password: password,
      );
      if (!_isSessionActive(sessionVersion)) return null;
      final preview = KdbxImportPreview(
        data: data,
        duplicateIndexes: _repository.findKdbxDuplicateIndexes(data),
      );
      _state = VaultAppState.unlocked;
      notifyListeners();
      return preview;
    } catch (error) {
      if (!_isSessionActive(sessionVersion)) return null;
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
    final sessionVersion = _sessionVersion;
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
      if (!_isSessionActive(sessionVersion)) return null;
      _state = VaultAppState.unlocked;
      notifyListeners();
      if (summary.itemCount > 0) _scheduleSync('KDBX 导入后自动同步');
      return summary;
    } catch (error) {
      if (!_isSessionActive(sessionVersion)) return null;
      _state = VaultAppState.unlocked;
      _errorMessage = _readableError(error);
      notifyListeners();
      return null;
    }
  }

  Future<Uint8List?> exportKdbx(String password) async {
    final vault = _repository.vault;
    if (vault == null) return null;
    final sessionVersion = _sessionVersion;
    _state = VaultAppState.saving;
    _errorMessage = null;
    notifyListeners();
    try {
      final bytes = await _kdbxTransferService.encode(
        vault: vault,
        password: password,
      );
      if (!_isSessionActive(sessionVersion)) return null;
      _state = VaultAppState.unlocked;
      notifyListeners();
      return bytes;
    } catch (error) {
      if (!_isSessionActive(sessionVersion)) return null;
      _state = VaultAppState.unlocked;
      _errorMessage = _readableError(error);
      notifyListeners();
      return null;
    }
  }

  void lock({bool automaticDeviceUnlock = true}) {
    _sessionVersion++;
    _periodicSyncTimer?.cancel();
    _debouncedSyncTimer?.cancel();
    _repository.lock();
    _automaticDeviceUnlock = automaticDeviceUnlock;
    _query = '';
    _errorMessage = null;
    _syncMessage = null;
    _state = VaultAppState.locked;
    notifyListeners();
  }

  void allowAutomaticDeviceUnlock() {
    if (_state != VaultAppState.locked || _automaticDeviceUnlock) return;
    _automaticDeviceUnlock = true;
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
    final sessionVersion = _sessionVersion;
    _state = busyState;
    _errorMessage = null;
    notifyListeners();
    try {
      await operation();
      if (sessionVersion != _sessionVersion || _repository.vault == null) {
        return false;
      }
      _state = VaultAppState.unlocked;
      notifyListeners();
      return true;
    } catch (error) {
      if (sessionVersion != _sessionVersion) return false;
      _state = fallbackState;
      _errorMessage = _readableError(error);
      notifyListeners();
      return false;
    }
  }

  bool _isSessionActive(int sessionVersion) =>
      sessionVersion == _sessionVersion && _repository.vault != null;

  String _readableError(Object error) => error
      .toString()
      .replaceFirst('FormatException: ', '')
      .replaceFirst('Bad state: ', '')
      .replaceFirst('Exception: ', '');
}
