import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/backup_repository.dart';
import '../../../data/services/backup_state_service.dart';
import '../../../domain/models/backup_entry.dart';
import '../vault/vault_view_model.dart';

class BackupViewModel extends ChangeNotifier {
  BackupViewModel({
    required BackupRepository repository,
    required VaultViewModel vaultViewModel,
  }) : _repository = repository,
       _vaultViewModel = vaultViewModel;

  static const _interval = Duration(days: 3);
  final BackupRepository _repository;
  final VaultViewModel _vaultViewModel;
  BackupState _state = const BackupState();
  List<BackupEntry> _local = const [];
  List<BackupEntry> _webDav = const [];
  bool _busy = false;
  String? _message;

  BackupState get state => _state;
  List<BackupEntry> get local => _local;
  List<BackupEntry> get webDav => _webDav;
  bool get busy => _busy;
  bool get actionsDisabled =>
      _busy || _vaultViewModel.state != VaultAppState.unlocked;
  String? get message => _message;

  Future<BackupExport?> prepareExport() async {
    if (actionsDisabled) return null;
    try {
      return await _vaultViewModel.runExclusiveVaultOperation(
        () async => _repository.prepareExport(),
      );
    } catch (error) {
      _message = _readable(error);
      notifyListeners();
      return null;
    }
  }

  Future<void> load() async {
    if (_vaultViewModel.state != VaultAppState.unlocked) return;
    try {
      await _vaultViewModel.runExclusiveVaultOperation(() async {
        _state = await _repository.loadState();
        _local = await _repository.localBackups();
        try {
          _webDav = await _repository.webDavBackups();
          final latest = _latestAutomatic(_webDav);
          if (latest != null) _state = _state.copyWith(lastWebDavAt: latest);
        } catch (_) {
          _webDav = const [];
        }
      });
    } catch (error) {
      _message = _readable(error);
    }
    notifyListeners();
  }

  Future<bool> setAutomatic(bool value) async {
    if (actionsDisabled) return false;
    _busy = true;
    _message = null;
    notifyListeners();
    try {
      await _vaultViewModel.runExclusiveVaultOperation(() async {
        await _repository.setAutomatic(value);
        _state = await _repository.loadState();
      });
      return true;
    } catch (error) {
      _message = '自动备份设置保存失败：${_readable(error)}';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> checkAutomatic() async {
    if (_busy || _vaultViewModel.state != VaultAppState.unlocked) return false;
    _busy = true;
    _message = null;
    notifyListeners();
    try {
      await _vaultViewModel.runExclusiveVaultOperation(() async {
        _state = await _repository.loadState();
        if (!_state.automaticEnabled) return;
        final now = DateTime.now().toUtc();
        final localDue = _due(_state.lastLocalAt, now);
        var webDavDue = false;
        String? webDavFailure;
        try {
          _webDav = await _repository.webDavBackups();
          webDavDue = _due(_latestAutomatic(_webDav), now);
        } catch (error) {
          webDavFailure = _readable(error);
        }
        final messages = <String>[];
        if (localDue) {
          try {
            await _repository.createLocal(prefix: 'auto');
            messages.add('本地自动备份成功');
          } catch (error) {
            messages.add('本地自动备份失败：${_readable(error)}');
          }
        }
        if (webDavDue) {
          try {
            await _repository.createWebDav(prefix: 'auto');
            messages.add('WebDAV 自动备份成功');
          } catch (error) {
            messages.add('WebDAV 自动备份失败：${_readable(error)}');
          }
        } else if (webDavFailure != null &&
            !webDavFailure.contains('尚未配置 WebDAV')) {
          messages.add('WebDAV 自动备份检查失败：$webDavFailure');
        }
        _message = messages.isEmpty ? null : messages.join('；');
      });
      return true;
    } catch (error) {
      _message = '自动备份检查失败：${_readable(error)}';
      return _vaultViewModel.state == VaultAppState.unlocked;
    } finally {
      _busy = false;
      if (_vaultViewModel.state == VaultAppState.unlocked) await load();
    }
  }

  Future<bool> createLocal() => _run(() => _repository.createLocal());
  Future<bool> createWebDav() => _run(() => _repository.createWebDav());
  Future<void> recordManualLocalBackup(String vaultId) async {
    _state = await _repository.recordManualLocalBackup(vaultId);
    notifyListeners();
  }

  Future<bool> delete(BackupEntry entry) =>
      _run(() => _repository.delete(entry), success: '备份已删除');

  Future<String?> read(BackupEntry entry) async {
    if (actionsDisabled) return null;
    try {
      return await _vaultViewModel.runExclusiveVaultOperation(
        () => _repository.read(entry),
      );
    } catch (error) {
      _message = _readable(error);
      notifyListeners();
      return null;
    }
  }

  Future<bool> restore(String encoded, String password) async {
    if (_busy) return false;
    _busy = true;
    _message = null;
    notifyListeners();
    try {
      final result = await _vaultViewModel.runExclusiveVaultOperation(
        () => _repository.restore(encoded, password),
      );
      _message = switch (result) {
        BackupRestoreResult(webDavSynced: true) => '恢复成功，已同步到 WebDAV',
        BackupRestoreResult(webDavConfigured: false) => '恢复成功；尚未配置 WebDAV',
        _ => '恢复成功，WebDAV 未同步，请稍后立即同步',
      };
      return true;
    } catch (error) {
      _message = _readable(error);
      return false;
    } finally {
      _busy = false;
      if (_vaultViewModel.state == VaultAppState.unlocked) await load();
    }
  }

  Future<bool> _run(
    Future<void> Function() operation, {
    String success = '备份成功',
  }) async {
    if (_busy) return false;
    _busy = true;
    _message = null;
    notifyListeners();
    try {
      await _vaultViewModel.runExclusiveVaultOperation(operation);
      _message = success;
      return true;
    } catch (error) {
      _message = _readable(error);
      return false;
    } finally {
      _busy = false;
      if (_vaultViewModel.state == VaultAppState.unlocked) await load();
    }
  }

  bool _due(DateTime? value, DateTime now) =>
      value == null || now.difference(value) >= _interval;

  DateTime? _latestAutomatic(List<BackupEntry> entries) {
    DateTime? latest;
    for (final entry in entries.where((entry) => entry.isAutomatic)) {
      if (latest == null || entry.createdAt.isAfter(latest)) {
        latest = entry.createdAt;
      }
    }
    return latest;
  }

  String _readable(Object error) => error
      .toString()
      .replaceFirst('FormatException: ', '')
      .replaceFirst('Bad state: ', '');
}
