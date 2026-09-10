import 'dart:math' as math;
import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/models/kdbx_transfer_data.dart';
import '../../../data/services/totp_service.dart';
import '../../../domain/models/totp_config.dart';
import '../../../domain/models/vault_item.dart';
import '../../../domain/models/vault_group.dart';
import '../../core/vault_brand.dart';
import '../../core/app_feedback.dart';
import '../settings/change_master_password_dialog.dart';
import '../settings/device_unlock_sheet.dart';
import '../settings/sync_history_screen.dart';
import '../settings/webdav_settings_screen.dart';
import 'vault_view_model.dart';

part 'vault_home_kdbx.dart';
part 'vault_home_list.dart';
part 'vault_home_groups.dart';
part 'vault_home_item_actions.dart';
part 'vault_home_item_viewer.dart';
part 'vault_home_item_editor.dart';
part 'vault_home_group_selector.dart';

class VaultHomeScreen extends StatelessWidget {
  const VaultHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<VaultViewModel>();
    return Scaffold(
      appBar: AppBar(
        title: const VaultBrand(compact: true),
        actions: [
          if (viewModel.busy)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          PopupMenuButton<_VaultMenuAction>(
            tooltip: '更多操作',
            color: Theme.of(context).colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onSelected: (action) => _handleMenu(context, action),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: _VaultMenuAction.sync,
                enabled: !viewModel.busy,
                child: const _MenuRow(icon: Icons.sync, label: '立即同步'),
              ),
              PopupMenuItem(
                value: _VaultMenuAction.webDav,
                enabled: !viewModel.busy,
                child: const _MenuRow(
                  icon: Icons.cloud_sync_outlined,
                  label: 'WebDAV 设置',
                ),
              ),
              PopupMenuItem(
                value: _VaultMenuAction.history,
                child: const _MenuRow(icon: Icons.history, label: '同步历史'),
              ),
              PopupMenuItem(
                value: _VaultMenuAction.groupManagement,
                enabled: !viewModel.busy,
                child: const _MenuRow(
                  icon: Icons.folder_outlined,
                  label: '分组管理',
                ),
              ),
              PopupMenuItem(
                value: _VaultMenuAction.changeMasterPassword,
                enabled: !viewModel.busy,
                child: const _MenuRow(icon: Icons.key_outlined, label: '修改主密码'),
              ),
              PopupMenuItem(
                value: _VaultMenuAction.deviceUnlock,
                enabled:
                    viewModel.deviceUnlockSupported &&
                    !viewModel.deviceUnlockBusy,
                child: _MenuRow(
                  icon: viewModel.deviceUnlockEnabled
                      ? Icons.phonelink_lock
                      : Icons.phonelink_lock_outlined,
                  label: viewModel.deviceUnlockSupported
                      ? (viewModel.deviceUnlockEnabled ? '关闭设备验证解锁' : '设备验证解锁')
                      : '设备验证不可用',
                  active: viewModel.deviceUnlockEnabled,
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: _VaultMenuAction.multiSelect,
                enabled: !viewModel.busy,
                child: const _MenuRow(
                  icon: Icons.checklist_outlined,
                  label: '多选操作',
                ),
              ),
              const PopupMenuItem(
                value: _VaultMenuAction.importKdbx,
                child: _MenuRow(
                  icon: Icons.file_download_outlined,
                  label: '导入 KDBX',
                ),
              ),
              const PopupMenuItem(
                value: _VaultMenuAction.exportKdbx,
                child: _MenuRow(
                  icon: Icons.file_upload_outlined,
                  label: '导出 KDBX',
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: _VaultMenuAction.lock,
                enabled: !viewModel.busy,
                child: const _MenuRow(icon: Icons.lock_outline, label: '锁定'),
              ),
              PopupMenuItem(
                value: _VaultMenuAction.togglePasswords,
                child: _MenuRow(
                  icon: viewModel.showPasswords
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  label: viewModel.showPasswords ? '隐藏密码' : '展示密码',
                  active: viewModel.showPasswords,
                ),
              ),
              PopupMenuItem(
                value: _VaultMenuAction.toggleWebsites,
                child: _MenuRow(
                  icon: viewModel.showWebsites
                      ? Icons.link_outlined
                      : Icons.link_off_outlined,
                  label: viewModel.showWebsites ? '隐藏网站' : '展示网站',
                  active: viewModel.showWebsites,
                ),
              ),
              PopupMenuItem(
                value: _VaultMenuAction.toggleTotp,
                child: _MenuRow(
                  icon: viewModel.showTotp
                      ? Icons.timer_outlined
                      : Icons.timer_off_outlined,
                  label: viewModel.showTotp ? '隐藏 TOTP' : '显示 TOTP',
                  active: viewModel.showTotp,
                ),
              ),
              PopupMenuItem(
                value: _VaultMenuAction.sortByTime,
                child: _MenuRow(
                  icon:
                      viewModel.sortOrder == VaultSortOrder.time &&
                          viewModel.sortReversed
                      ? Icons.south_outlined
                      : Icons.north_outlined,
                  label: viewModel.sortOrder == VaultSortOrder.time
                      ? (viewModel.sortReversed ? '按时间倒序' : '按时间正序')
                      : '按时间排序',
                  active: viewModel.sortOrder == VaultSortOrder.time,
                ),
              ),
              PopupMenuItem(
                value: _VaultMenuAction.sortByName,
                child: _MenuRow(
                  icon:
                      viewModel.sortOrder == VaultSortOrder.name &&
                          viewModel.sortReversed
                      ? Icons.south_outlined
                      : Icons.north_outlined,
                  label: viewModel.sortOrder == VaultSortOrder.name
                      ? (viewModel.sortReversed ? '按名称倒序' : '按名称正序')
                      : '按名称排序',
                  active: viewModel.sortOrder == VaultSortOrder.name,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (viewModel.syncProgress case final progress?) ...[
            const LinearProgressIndicator(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text(progress),
            ),
          ],
          if (viewModel.webDavConflict)
            MaterialBanner(
              content: const Text('检测到其他设备使用了不同的 WebDAV 配置，本次同步已保留当前设备配置。'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const WebDavSettingsScreen(),
                    ),
                  ),
                  child: const Text('检查配置'),
                ),
              ],
            ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final list = _VaultList(viewModel: viewModel);
                if (constraints.maxWidth >= 900) {
                  return Row(
                    children: [
                      SizedBox(width: 360, child: list),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: Center(
                          child: Text(
                            '选择一个条目，或创建新密码',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ),
                    ],
                  );
                }
                return list;
              },
            ),
          ),
        ],
      ),
      floatingActionButton: viewModel.selectionMode
          ? null
          : FloatingActionButton.extended(
              key: const Key('add-item'),
              onPressed: viewModel.busy
                  ? null
                  : () => _openEditor(context, viewModel),
              icon: const Icon(Icons.add),
              label: const Text('新建'),
            ),
    );
  }
}

enum _VaultMenuAction {
  sync,
  webDav,
  history,
  groupManagement,
  changeMasterPassword,
  deviceUnlock,
  importKdbx,
  exportKdbx,
  multiSelect,
  lock,
  togglePasswords,
  toggleWebsites,
  toggleTotp,
  sortByTime,
  sortByName,
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? Theme.of(context).colorScheme.primary : null;
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 12),
        Text(label, style: color == null ? null : TextStyle(color: color)),
      ],
    );
  }
}

Future<void> _handleMenu(BuildContext context, _VaultMenuAction action) async {
  final viewModel = context.read<VaultViewModel>();
  switch (action) {
    case _VaultMenuAction.sync:
      await _sync(context, viewModel);
    case _VaultMenuAction.webDav:
      await Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (_) => const WebDavSettingsScreen()),
      );
    case _VaultMenuAction.history:
      await Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (_) => const SyncHistoryScreen()),
      );
    case _VaultMenuAction.groupManagement:
      await _showGroupManagement(context, viewModel);
    case _VaultMenuAction.changeMasterPassword:
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const ChangeMasterPasswordDialog(),
      );
    case _VaultMenuAction.deviceUnlock:
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) =>
            DeviceUnlockSheet(disable: viewModel.deviceUnlockEnabled),
      );
    case _VaultMenuAction.importKdbx:
      await _importKdbx(context, viewModel);
    case _VaultMenuAction.exportKdbx:
      await _exportKdbx(context, viewModel);
    case _VaultMenuAction.multiSelect:
      viewModel.startSelectionMode();
    case _VaultMenuAction.lock:
      viewModel.lock();
    case _VaultMenuAction.togglePasswords:
      viewModel.setShowPasswords(!viewModel.showPasswords);
    case _VaultMenuAction.toggleWebsites:
      viewModel.setShowWebsites(!viewModel.showWebsites);
    case _VaultMenuAction.toggleTotp:
      viewModel.setShowTotp(!viewModel.showTotp);
    case _VaultMenuAction.sortByTime:
      viewModel.setSortOrder(VaultSortOrder.time);
    case _VaultMenuAction.sortByName:
      viewModel.setSortOrder(VaultSortOrder.name);
  }
}
