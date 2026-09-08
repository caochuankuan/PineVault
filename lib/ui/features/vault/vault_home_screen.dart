import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/models/kdbx_transfer_data.dart';
import '../../../domain/models/vault_item.dart';
import '../../../domain/models/vault_group.dart';
import '../../core/vault_brand.dart';
import '../../core/app_feedback.dart';
import '../settings/change_master_password_dialog.dart';
import '../settings/device_unlock_sheet.dart';
import '../settings/sync_history_screen.dart';
import '../settings/webdav_settings_screen.dart';
import 'vault_view_model.dart';

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
    case _VaultMenuAction.sortByTime:
      viewModel.setSortOrder(VaultSortOrder.time);
    case _VaultMenuAction.sortByName:
      viewModel.setSortOrder(VaultSortOrder.name);
  }
}

Future<void> _importKdbx(BuildContext context, VaultViewModel viewModel) async {
  PlatformFile? file;
  try {
    file = await FilePicker.pickFile(
      dialogTitle: '选择 KDBX 密码库',
      type: FileType.custom,
      allowedExtensions: const ['kdbx'],
    );
  } catch (error) {
    if (context.mounted) _showMessage(context, '无法选择文件：$error');
    return;
  }
  if (file == null || !context.mounted) return;

  final password = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _KdbxPasswordSheet.import(fileName: file!.name),
  );
  if (password == null || !context.mounted) return;

  Uint8List bytes;
  try {
    bytes = await file.readAsBytes();
  } catch (error) {
    if (context.mounted) _showMessage(context, '无法读取 KDBX 文件：$error');
    return;
  }
  final preview = await viewModel.prepareKdbxImport(
    bytes: bytes,
    password: password,
  );
  if (!context.mounted) return;
  if (preview == null) {
    _showMessage(context, viewModel.errorMessage ?? 'KDBX 导入失败');
    return;
  }
  if (preview.data.entries.isEmpty) {
    _showMessage(context, 'KDBX 中没有可导入的密码条目');
    return;
  }
  final selectedIndexes = await showModalBottomSheet<Set<int>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _KdbxImportReviewSheet(preview: preview),
  );
  if (selectedIndexes == null || !context.mounted) return;
  final summary = await viewModel.completeKdbxImport(preview, selectedIndexes);
  if (!context.mounted) return;
  if (summary == null) {
    _showMessage(context, viewModel.errorMessage ?? 'KDBX 导入失败');
    return;
  }
  _showMessage(
    context,
    summary.itemCount == 0
        ? '没有选择要导入的条目'
        : '已导入 ${summary.itemCount} 条密码，新增 ${summary.createdGroupCount} 个分组',
  );
}

class _KdbxImportReviewSheet extends StatefulWidget {
  const _KdbxImportReviewSheet({required this.preview});

  final KdbxImportPreview preview;

  @override
  State<_KdbxImportReviewSheet> createState() => _KdbxImportReviewSheetState();
}

class _KdbxImportReviewSheetState extends State<_KdbxImportReviewSheet> {
  late Set<int> _selectedIndexes;

  List<KdbxImportEntry> get _entries => widget.preview.data.entries;

  @override
  void initState() {
    super.initState();
    _selectedIndexes = {
      for (var index = 0; index < _entries.length; index++)
        if (!widget.preview.duplicateIndexes.contains(index)) index,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final problemCount = [
      for (var index = 0; index < _entries.length; index++)
        if (_issuesFor(index).isNotEmpty) index,
    ].length;
    return FractionallySizedBox(
      heightFactor: 0.9,
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '选择导入条目',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '共 ${_entries.length} 条 · 重复 ${widget.preview.duplicateCount} 条 · 有问题 $problemCount 条',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: _toggleAll,
                      icon: Icon(
                        _selectedIndexes.length == _entries.length
                            ? Icons.deselect_outlined
                            : Icons.select_all_outlined,
                      ),
                      label: Text(
                        _selectedIndexes.length == _entries.length
                            ? '取消全选'
                            : '全选',
                      ),
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      onPressed: _selectNormal,
                      icon: const Icon(Icons.verified_outlined),
                      label: const Text('只选正常项'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  itemCount: _entries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final entry = _entries[index];
                    final issues = _issuesFor(index);
                    final selected = _selectedIndexes.contains(index);
                    return Card(
                      elevation: 0,
                      margin: EdgeInsets.zero,
                      color: issues.isEmpty
                          ? theme.colorScheme.surfaceContainerLow
                          : theme.colorScheme.surfaceContainer,
                      child: CheckboxListTile(
                        value: selected,
                        onChanged: (_) => _toggle(index),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: const EdgeInsets.fromLTRB(8, 4, 14, 4),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                entry.title.trim().isEmpty
                                    ? '（无名称）'
                                    : entry.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            ...issues.map(
                              (issue) => Padding(
                                padding: const EdgeInsets.only(left: 5),
                                child: _ImportIssueBadge(issue: issue),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            [
                              entry.groupName,
                              if (entry.username.trim().isNotEmpty)
                                entry.username,
                              if (entry.url.trim().isNotEmpty) entry.url,
                            ].join(' · '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(
                    top: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('取消'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: _selectedIndexes.isEmpty
                            ? null
                            : () => Navigator.pop(
                                context,
                                Set<int>.from(_selectedIndexes),
                              ),
                        child: Text('导入（${_selectedIndexes.length}）'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<_ImportIssue> _issuesFor(int index) {
    final entry = _entries[index];
    return [
      if (widget.preview.duplicateIndexes.contains(index))
        _ImportIssue.duplicate,
      if (entry.title.trim().isEmpty) _ImportIssue.missingTitle,
      if (entry.password.isEmpty) _ImportIssue.missingPassword,
    ];
  }

  void _toggle(int index) {
    setState(() {
      if (!_selectedIndexes.remove(index)) _selectedIndexes.add(index);
    });
  }

  void _toggleAll() {
    setState(() {
      _selectedIndexes = _selectedIndexes.length == _entries.length
          ? <int>{}
          : {for (var index = 0; index < _entries.length; index++) index};
    });
  }

  void _selectNormal() {
    setState(() {
      _selectedIndexes = {
        for (var index = 0; index < _entries.length; index++)
          if (_issuesFor(index).isEmpty) index,
      };
    });
  }
}

enum _ImportIssue { duplicate, missingTitle, missingPassword }

class _ImportIssueBadge extends StatelessWidget {
  const _ImportIssueBadge({required this.issue});

  final _ImportIssue issue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color) = switch (issue) {
      _ImportIssue.duplicate => ('重复', Colors.orange.shade800),
      _ImportIssue.missingTitle => ('缺名称', theme.colorScheme.error),
      _ImportIssue.missingPassword => ('缺密码', theme.colorScheme.error),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

Future<void> _exportKdbx(BuildContext context, VaultViewModel viewModel) async {
  final password = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _KdbxPasswordSheet.export(),
  );
  if (password == null || !context.mounted) return;

  final bytes = await viewModel.exportKdbx(password);
  if (bytes == null || !context.mounted) {
    if (context.mounted) {
      _showMessage(context, viewModel.errorMessage ?? 'KDBX 导出失败');
    }
    return;
  }

  final now = DateTime.now();
  final fileName =
      '松匣-${now.year}${_twoDigits(now.month)}${_twoDigits(now.day)}-'
      '${_twoDigits(now.hour)}${_twoDigits(now.minute)}.kdbx';
  try {
    final saved = await FilePicker.saveFile(
      dialogTitle: '导出 KDBX 密码库',
      fileName: fileName,
      bytes: bytes,
      mimeType: 'application/x-keepass2',
    );
    if (saved != null && context.mounted) {
      _showMessage(context, 'KDBX 已导出');
    }
  } catch (error) {
    if (context.mounted) _showMessage(context, '无法保存 KDBX 文件：$error');
  }
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

void _showMessage(BuildContext context, String message) {
  showAppMessage(context, message);
}

enum _KdbxPasswordMode { import, export }

class _KdbxPasswordSheet extends StatefulWidget {
  const _KdbxPasswordSheet.import({required this.fileName})
    : mode = _KdbxPasswordMode.import;

  const _KdbxPasswordSheet.export()
    : mode = _KdbxPasswordMode.export,
      fileName = null;

  final _KdbxPasswordMode mode;
  final String? fileName;

  @override
  State<_KdbxPasswordSheet> createState() => _KdbxPasswordSheetState();
}

class _KdbxPasswordSheetState extends State<_KdbxPasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _obscurePassword = true;

  bool get _isExport => widget.mode == _KdbxPasswordMode.export;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _isExport ? '导出 KDBX' : '导入 KDBX',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isExport
                        ? '设置此 KDBX 文件自己的主密码，与松匣主密码互不影响。'
                        : '${widget.fileName}\n此密码只用于本次解密，不会保存到松匣。',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _password,
                    autofocus: true,
                    obscureText: _obscurePassword,
                    textInputAction: _isExport
                        ? TextInputAction.next
                        : TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: _isExport ? '设置 KDBX 主密码' : 'KDBX 主密码',
                      prefixIcon: const Icon(Icons.key_outlined),
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if ((value ?? '').isEmpty) return '请输入 KDBX 主密码';
                      if (_isExport && value!.length < 8) {
                        return 'KDBX 主密码至少需要 8 个字符';
                      }
                      return null;
                    },
                    onFieldSubmitted: _isExport ? null : (_) => _submit(),
                  ),
                  if (_isExport) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirmation,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: '确认 KDBX 主密码',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      validator: (value) =>
                          value != _password.text ? '两次输入的密码不一致' : null,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('取消'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _submit,
                          child: Text(_isExport ? '生成文件' : '开始导入'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(context, _password.text);
  }
}

Future<void> _sync(BuildContext context, VaultViewModel viewModel) async {
  final succeeded = await viewModel.sync();
  if (!context.mounted) return;
  final message = succeeded ? viewModel.syncMessage : viewModel.errorMessage;
  showAppMessage(context, message ?? '同步失败，请重试');
}

class _VaultList extends StatelessWidget {
  const _VaultList({required this.viewModel});

  final VaultViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final items = viewModel.items;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: TextField(
            key: const Key('vault-search'),
            onChanged: viewModel.setQuery,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: '搜索名称、用户名或网站',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 15,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: Theme.of(
                    context,
                  ).colorScheme.outlineVariant.withValues(alpha: 0.55),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
        if (viewModel.selectionMode)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Text('已选择 ${viewModel.selectedItemIds.length} 项'),
                const Spacer(),
                TextButton(
                  onPressed: viewModel.items.isEmpty
                      ? null
                      : viewModel.selectAllItems,
                  child: const Text('全选'),
                ),
                TextButton(
                  onPressed: viewModel.clearItemSelection,
                  child: const Text('清除'),
                ),
                IconButton(
                  tooltip: '退出多选',
                  onPressed: viewModel.exitSelectionMode,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 16, right: 8, bottom: 8),
            children: [
              FilterChip(
                label: const Text('全部'),
                selected: viewModel.selectedGroupId == 'all',
                onSelected: (_) => viewModel.setSelectedGroup('all'),
              ),
              ...viewModel.groups.map(
                (group) => Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: FilterChip(
                    label: Text(group.name),
                    selected: viewModel.selectedGroupId == group.id,
                    onSelected: (_) => viewModel.setSelectedGroup(group.id),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: const Text('新建分组'),
                  onPressed: viewModel.busy
                      ? null
                      : () => _createGroup(context, viewModel),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? _EmptyVault(hasQuery: viewModel.query.isNotEmpty)
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final details = <String>[
                      item.username.isEmpty ? '未设置用户名' : item.username,
                      if (viewModel.showWebsites && item.urls.isNotEmpty)
                        item.urls.first,
                      if (viewModel.showPasswords)
                        item.password.isEmpty ? '未设置密码' : item.password,
                    ].join(' · ');
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      elevation: 0,
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: viewModel.selectionMode
                            ? () => viewModel.toggleItemSelection(item.id)
                            : () => _openViewer(context, viewModel, item),
                        onLongPress: viewModel.selectionMode
                            ? null
                            : () => _showItemActions(context, item),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              if (viewModel.selectionMode)
                                Padding(
                                  padding: const EdgeInsets.only(right: 2),
                                  child: Checkbox(
                                    value: viewModel.selectedItemIds.contains(
                                      item.id,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    onChanged: (_) =>
                                        viewModel.toggleItemSelection(item.id),
                                  ),
                                )
                              else
                                CircleAvatar(
                                  child: Text(
                                    item.title.isEmpty
                                        ? '?'
                                        : item.title[0].toUpperCase(),
                                  ),
                                ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      details,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              if (item.favorite)
                                const Padding(
                                  padding: EdgeInsets.only(left: 8),
                                  child: Icon(Icons.star, color: Colors.amber),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (viewModel.selectionMode && viewModel.selectedItemIds.isNotEmpty)
          _BatchActionBar(viewModel: viewModel),
      ],
    );
  }
}

class _BatchActionBar extends StatelessWidget {
  const _BatchActionBar({required this.viewModel});

  final VaultViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              tooltip: '收藏/取消收藏',
              onPressed: viewModel.busy ? null : () => _toggleFavorite(context),
              icon: const Icon(Icons.star_outline),
            ),
            IconButton(
              tooltip: '移动分组',
              onPressed: viewModel.busy ? null : () => _moveGroup(context),
              icon: const Icon(Icons.drive_file_move_outlined),
            ),
            IconButton(
              tooltip: '复制全部',
              onPressed: () => _copyAll(context),
              icon: const Icon(Icons.copy_all_outlined),
            ),
            IconButton(
              tooltip: '删除',
              onPressed: viewModel.busy ? null : () => _delete(context),
              icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleFavorite(BuildContext context) async {
    final allFavorite = viewModel.selectedItems.every((item) => item.favorite);
    final ok = await viewModel.batchSetFavorite(!allFavorite);
    if (context.mounted && ok) {
      _showMessage(context, allFavorite ? '已取消收藏' : '已收藏');
    }
  }

  Future<void> _moveGroup(BuildContext context) async {
    final groupId = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 12),
          children: [
            const ListTile(title: Text('移动到分组')),
            for (final group in viewModel.groups)
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(group.name),
                onTap: () => Navigator.pop(context, group.id),
              ),
          ],
        ),
      ),
    );
    if (groupId == null || !context.mounted) return;
    final ok = await viewModel.batchMoveToGroup(groupId);
    if (context.mounted && ok) _showMessage(context, '已移动到分组');
  }

  Future<void> _copyAll(BuildContext context) async {
    final selectedItems = viewModel.selectedItems;
    final selectedCount = selectedItems.length;
    final text = selectedItems
        .map(
          (item) => [
            '名称：${item.title}',
            '账号：${item.username}',
            '密码：${item.password}',
            '网站：${item.urls.isEmpty ? '' : item.urls.first}',
            '备注：${item.notes}',
            if (item.tags.isNotEmpty) '标签：${item.tags.join(', ')}',
          ].join('\n'),
        )
        .join('\n\n');
    await Clipboard.setData(ClipboardData(text: text));
    viewModel.exitSelectionMode();
    if (context.mounted) {
      _showMessage(context, '已复制 $selectedCount 条记录');
    }
  }

  Future<void> _delete(BuildContext context) async {
    final count = viewModel.selectedItemIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除 $count 条记录？'),
        content: const Text('删除后会自动同步到其他设备。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final ok = await viewModel.batchDelete();
    if (context.mounted && ok) _showMessage(context, '已删除 $count 条记录');
  }
}

Future<void> _showGroupManagement(
  BuildContext context,
  VaultViewModel viewModel,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _GroupManagementSheet(),
  );
}

class _GroupManagementSheet extends StatelessWidget {
  const _GroupManagementSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.78;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 640, maxHeight: maxHeight),
        child: Material(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: Consumer<VaultViewModel>(
              builder: (context, viewModel, _) {
                final groups = viewModel.groups;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 12, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '分组管理',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: '关闭',
                            onPressed: viewModel.busy
                                ? null
                                : () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '拖动右侧手柄调整顺序',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    Flexible(
                      child: ReorderableListView.builder(
                        buildDefaultDragHandles: false,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        itemCount: groups.length,
                        onReorder: viewModel.busy
                            ? (_, _) {}
                            : (oldIndex, newIndex) async {
                                if (oldIndex == 0 || newIndex == 0) return;
                                await viewModel.reorderGroups(
                                  oldIndex,
                                  newIndex,
                                );
                              },
                        itemBuilder: (context, index) {
                          final group = groups[index];
                          final isDefault = group.id == 'default';
                          return Card(
                            key: ValueKey(group.id),
                            margin: const EdgeInsets.only(bottom: 8),
                            elevation: 0,
                            color: theme.colorScheme.surfaceContainerLow,
                            child: ListTile(
                              leading: Icon(
                                isDefault
                                    ? Icons.folder_special_outlined
                                    : Icons.folder_outlined,
                                color: isDefault
                                    ? theme.colorScheme.primary
                                    : null,
                              ),
                              title: Text(
                                group.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${viewModel.itemCountForGroup(group.id)} 条记录',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: isDefault ? '默认分组不可重命名' : '重命名',
                                    onPressed: viewModel.busy || isDefault
                                        ? null
                                        : () => _renameGroup(
                                            context,
                                            viewModel,
                                            group,
                                          ),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                  IconButton(
                                    tooltip: isDefault ? '默认分组不可删除' : '删除',
                                    onPressed: viewModel.busy || isDefault
                                        ? null
                                        : () => _deleteGroup(
                                            context,
                                            viewModel,
                                            group,
                                          ),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                  ReorderableDelayedDragStartListener(
                                    index: index,
                                    enabled: !isDefault && !viewModel.busy,
                                    child: const Padding(
                                      padding: EdgeInsets.all(8),
                                      child: Icon(Icons.drag_handle),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: viewModel.busy
                              ? null
                              : () => _createGroup(context, viewModel),
                          icon: const Icon(Icons.add),
                          label: const Text('新建分组'),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _renameGroup(
  BuildContext context,
  VaultViewModel viewModel,
  VaultGroup group,
) async {
  final name = await _showGroupNameSheet(
    context,
    title: '重命名分组',
    initialName: group.name,
    actionLabel: '保存',
  );
  if (name == null || !context.mounted) return;
  final succeeded = await viewModel.renameGroup(group.id, name);
  if (context.mounted && succeeded) showAppMessage(context, '分组已重命名');
  if (context.mounted && !succeeded) {
    showAppMessage(context, viewModel.errorMessage ?? '重命名分组失败');
  }
}

Future<void> _deleteGroup(
  BuildContext context,
  VaultViewModel viewModel,
  VaultGroup group,
) async {
  final count = viewModel.itemCountForGroup(group.id);
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '删除分组',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              count == 0
                  ? '确定删除“${group.name}”吗？'
                  : '“${group.name}”中有 $count 条记录，删除后会移动到“未分组”，不会删除记录。',
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('删除'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  if (confirmed != true || !context.mounted) return;
  final succeeded = await viewModel.deleteGroup(group.id);
  if (context.mounted && succeeded) showAppMessage(context, '分组已删除');
  if (context.mounted && !succeeded) {
    showAppMessage(context, viewModel.errorMessage ?? '删除分组失败');
  }
}

Future<void> _createGroup(
  BuildContext context,
  VaultViewModel viewModel,
) async {
  final name = await _showGroupNameSheet(
    context,
    title: '新建分组',
    actionLabel: '创建',
  );
  if (name == null || !context.mounted) return;
  final created = await viewModel.createGroup(name);
  if (!context.mounted || created) return;
  showAppMessage(context, viewModel.errorMessage ?? '创建分组失败');
}

Future<String?> _showGroupNameSheet(
  BuildContext context, {
  required String title,
  String initialName = '',
  required String actionLabel,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _GroupNameSheet(
      title: title,
      initialName: initialName,
      actionLabel: actionLabel,
    ),
  );
}

class _GroupNameSheet extends StatefulWidget {
  const _GroupNameSheet({
    required this.title,
    required this.initialName,
    required this.actionLabel,
  });

  final String title;
  final String initialName;
  final String actionLabel;

  @override
  State<_GroupNameSheet> createState() => _GroupNameSheetState();
}

class _GroupNameSheetState extends State<_GroupNameSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  maxLength: 30,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: '分组名称',
                    prefixIcon: Icon(Icons.folder_outlined),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('取消'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _submit,
                        child: Text(widget.actionLabel),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, name);
  }
}

enum _ItemAction { all, username, password, website, notes, openWebsite }

Future<void> _showItemActions(BuildContext context, VaultItem item) async {
  final action = await showModalBottomSheet<_ItemAction>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Wrap(
        children: [
          ListTile(
            title: Text(item.title),
            subtitle: const Text('选择操作'),
            leading: const Icon(Icons.key_outlined),
          ),
          ListTile(
            leading: const Icon(Icons.copy_all_outlined),
            title: const Text('复制全部'),
            onTap: () => Navigator.pop(context, _ItemAction.all),
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('复制账号'),
            onTap: () => Navigator.pop(context, _ItemAction.username),
          ),
          ListTile(
            leading: const Icon(Icons.password_outlined),
            title: const Text('复制密码'),
            onTap: () => Navigator.pop(context, _ItemAction.password),
          ),
          ListTile(
            leading: const Icon(Icons.link_outlined),
            title: const Text('复制网站'),
            onTap: () => Navigator.pop(context, _ItemAction.website),
          ),
          ListTile(
            leading: const Icon(Icons.notes_outlined),
            title: const Text('复制备注'),
            onTap: () => Navigator.pop(context, _ItemAction.notes),
          ),
          ListTile(
            leading: const Icon(Icons.open_in_new_outlined),
            title: const Text('打开网站'),
            enabled: item.urls.isNotEmpty,
            onTap: item.urls.isEmpty
                ? null
                : () => Navigator.pop(context, _ItemAction.openWebsite),
          ),
          const SizedBox(height: 20),
        ],
      ),
    ),
  );
  if (!context.mounted || action == null) return;
  switch (action) {
    case _ItemAction.all:
      await _copyItemText(context, _allItemText(item), '全部信息');
    case _ItemAction.username:
      await _copyItemText(context, item.username, '账号');
    case _ItemAction.password:
      await _copyItemText(context, item.password, '密码');
    case _ItemAction.website:
      await _copyItemText(
        context,
        item.urls.isEmpty ? '' : item.urls.first,
        '网站',
      );
    case _ItemAction.notes:
      await _copyItemText(context, item.notes, '备注');
    case _ItemAction.openWebsite:
      await _launchWebsite(context, item.urls.first);
  }
}

String _allItemText(VaultItem item) => [
  '名称：${item.title}',
  '账号：${item.username}',
  '密码：${item.password}',
  '网站：${item.urls.isEmpty ? '' : item.urls.first}',
  '备注：${item.notes}',
].join('\n');

Future<void> _copyItemText(
  BuildContext context,
  String value,
  String label,
) async {
  await Clipboard.setData(ClipboardData(text: value));
  if (!context.mounted) return;
  showAppMessage(context, '$label已复制');
}

Future<void> _launchWebsite(BuildContext context, String value) async {
  final trimmed = value.trim();
  final uri = Uri.tryParse(
    trimmed.contains('://') ? trimmed : 'https://$trimmed',
  );
  if (uri == null || uri.host.isEmpty) {
    if (context.mounted) {
      showAppMessage(context, '网站地址无效');
    }
    return;
  }
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    showAppMessage(context, '无法打开网站');
  }
}

class _EmptyVault extends StatelessWidget {
  const _EmptyVault({required this.hasQuery});

  final bool hasQuery;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasQuery ? Icons.search_off : Icons.key_off_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            hasQuery ? '没有匹配的条目' : '密码库还是空的',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (!hasQuery) ...[
            const SizedBox(height: 8),
            const Text('点击“新建”保存第一条密码。'),
          ],
        ],
      ),
    );
  }
}

Future<void> _openEditor(
  BuildContext context,
  VaultViewModel viewModel, [
  VaultItem? item,
]) async {
  final window = MediaQuery.sizeOf(context);
  if (window.width < 600) {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ItemEditorDialog(viewModel: viewModel, item: item),
    );
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 560,
        height: (window.height * 0.82).clamp(520.0, 720.0),
        child: _ItemEditorDialog(viewModel: viewModel, item: item),
      ),
    ),
  );
}

Future<void> _openViewer(
  BuildContext context,
  VaultViewModel viewModel,
  VaultItem item,
) async {
  final window = MediaQuery.sizeOf(context);
  _ViewerAction? action;
  if (window.width < 600) {
    action = await showModalBottomSheet<_ViewerAction>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        child: _ItemViewer(viewModel: viewModel, item: item),
      ),
    );
  } else {
    action = await showDialog<_ViewerAction>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 560,
          height: (window.height * 0.72).clamp(460.0, 620.0),
          child: _ItemViewer(viewModel: viewModel, item: item),
        ),
      ),
    );
  }
  if (action == _ViewerAction.edit && context.mounted) {
    await _openEditor(context, viewModel, item);
  }
}

enum _ViewerAction { edit }

class _ItemViewer extends StatefulWidget {
  const _ItemViewer({required this.viewModel, required this.item});

  final VaultViewModel viewModel;
  final VaultItem item;

  @override
  State<_ItemViewer> createState() => _ItemViewerState();
}

class _ItemViewerState extends State<_ItemViewer> {
  bool _obscurePassword = true;
  bool _busy = false;
  OverlayEntry? _toastEntry;

  @override
  void dispose() {
    _toastEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).width < 600;

    Widget valueRow(
      String label,
      String value,
      IconData icon, {
      VoidCallback? onTap,
      VoidCallback? onCopy,
      VoidCallback? onOpen,
    }) {
      final content = Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(label, style: theme.textTheme.labelMedium),
                          if (onCopy != null)
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 28,
                                minHeight: 28,
                              ),
                              style: IconButton.styleFrom(
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              tooltip: '复制$label',
                              onPressed: onCopy,
                              icon: const Icon(Icons.copy_outlined, size: 17),
                            ),
                          if (onOpen != null)
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 28,
                                minHeight: 28,
                              ),
                              style: IconButton.styleFrom(
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              tooltip: '打开$label',
                              onPressed: onOpen,
                              icon: const Icon(
                                Icons.open_in_new_outlined,
                                size: 17,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      SelectableText(
                        value.isEmpty ? '未设置' : value,
                        style: theme.textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return onTap == null
          ? content
          : GestureDetector(onTap: onTap, child: content);
    }

    final password = _obscurePassword
        ? ('•' * widget.item.password.length)
        : widget.item.password;

    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: compact
            ? const BorderRadius.vertical(top: Radius.circular(28))
            : BorderRadius.circular(28),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, compact ? 12 : 20, 20, 12),
          child: Column(
            mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
            children: [
              if (compact)
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              Row(
                children: [
                  CircleAvatar(
                    child: Text(
                      widget.item.title.isEmpty
                          ? '?'
                          : widget.item.title[0].toUpperCase(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.item.title,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.item.favorite)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Icon(Icons.star, color: Colors.amber),
                          ),
                      ],
                    ),
                  ),
                  if (compact)
                    IconButton(
                      tooltip: '关闭',
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                fit: compact ? FlexFit.loose : FlexFit.tight,
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.viewInsetsOf(context).bottom + 8,
                  ),
                  child: Column(
                    children: [
                      valueRow(
                        '用户名',
                        widget.item.username,
                        Icons.person_outline,
                        onTap: widget.item.username.isEmpty
                            ? null
                            : () => _copy(widget.item.username, '用户名'),
                        onCopy: widget.item.username.isEmpty
                            ? null
                            : () => _copy(widget.item.username, '用户名'),
                      ),
                      GestureDetector(
                        onTap: widget.item.password.isEmpty
                            ? null
                            : () => _copy(widget.item.password, '密码'),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 13,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.key_outlined,
                                    size: 20,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              '密码',
                                              style:
                                                  theme.textTheme.labelMedium,
                                            ),
                                            if (widget.item.password.isNotEmpty)
                                              IconButton(
                                                visualDensity:
                                                    VisualDensity.compact,
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(
                                                      minWidth: 32,
                                                      minHeight: 28,
                                                    ),
                                                tooltip: '复制密码',
                                                onPressed: () => _copy(
                                                  widget.item.password,
                                                  '密码',
                                                ),
                                                icon: const Icon(
                                                  Icons.copy_outlined,
                                                  size: 17,
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        SelectableText(
                                          password,
                                          style: theme.textTheme.bodyLarge,
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: _obscurePassword ? '显示密码' : '隐藏密码',
                                    onPressed: () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      valueRow(
                        '网站',
                        widget.item.urls.isEmpty ? '' : widget.item.urls.first,
                        Icons.link_outlined,
                        onTap: widget.item.urls.isEmpty
                            ? null
                            : () => _openWebsite(widget.item.urls.first),
                        onCopy: widget.item.urls.isEmpty
                            ? null
                            : () => _copy(widget.item.urls.first, '网站'),
                        onOpen: widget.item.urls.isEmpty
                            ? null
                            : () => _openWebsite(widget.item.urls.first),
                      ),
                      if (widget.item.notes.isNotEmpty)
                        valueRow(
                          '备注',
                          widget.item.notes,
                          Icons.notes_outlined,
                          onCopy: () => _copy(widget.item.notes, '备注'),
                        ),
                      if (widget.item.tags.isNotEmpty)
                        valueRow(
                          '标签',
                          widget.item.tags.join(' · '),
                          Icons.sell_outlined,
                          onCopy: () =>
                              _copy(widget.item.tags.join(', '), '标签'),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (compact)
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                        onPressed: _busy ? null : _delete,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('删除', softWrap: false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                        onPressed: _busy ? null : () => Navigator.pop(context),
                        child: const Text('关闭', softWrap: false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                        onPressed: _busy ? null : _edit,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('编辑', softWrap: false),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: _busy ? null : _delete,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('删除'),
                    ),
                    const Spacer(),
                    OutlinedButton(
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      child: const Text('关闭'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: _busy ? null : _edit,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('编辑'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _edit() {
    Navigator.pop(context, _ViewerAction.edit);
  }

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    _showToast('$label已复制');
  }

  Future<void> _openWebsite(String value) async {
    final trimmed = value.trim();
    final normalized = trimmed.contains('://') ? trimmed : 'https://$trimmed';
    final uri = Uri.tryParse(normalized);
    if (uri == null || uri.host.isEmpty) {
      if (mounted) _showToast('网站地址无效');
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      _showToast('无法打开网站');
    }
  }

  void _showToast(String message) {
    _toastEntry?.remove();
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        left: 24,
        right: 24,
        bottom: 92,
        child: IgnorePointer(
          child: Center(
            child: Material(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    _toastEntry = entry;
    Overlay.of(context).insert(entry);
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (_toastEntry == entry) {
        entry.remove();
        _toastEntry = null;
      }
    });
  }

  Future<void> _delete() async {
    setState(() => _busy = true);
    final deleted = await widget.viewModel.deleteItem(widget.item);
    if (!mounted) return;
    if (deleted) {
      Navigator.pop(context);
    } else {
      setState(() => _busy = false);
      showAppMessage(context, widget.viewModel.errorMessage ?? '删除失败，请重试');
    }
  }
}

class _ItemEditorDialog extends StatefulWidget {
  const _ItemEditorDialog({required this.viewModel, this.item});

  final VaultViewModel viewModel;
  final VaultItem? item;

  @override
  State<_ItemEditorDialog> createState() => _ItemEditorDialogState();
}

class _ItemEditorDialogState extends State<_ItemEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _username;
  late final TextEditingController _password;
  late final TextEditingController _url;
  late final TextEditingController _notes;
  late final TextEditingController _tags;
  late bool _favorite;
  late String _groupId;
  bool _obscurePassword = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _title = TextEditingController(text: item?.title ?? '');
    _username = TextEditingController(text: item?.username ?? '');
    _password = TextEditingController(text: item?.password ?? '');
    _url = TextEditingController(
      text: item == null || item.urls.isEmpty ? '' : item.urls.first,
    );
    _notes = TextEditingController(text: item?.notes ?? '');
    _tags = TextEditingController(text: item?.tags.join(', ') ?? '');
    _favorite = item?.favorite ?? false;
    _groupId = item?.groupId ?? 'default';
  }

  @override
  void dispose() {
    _title.dispose();
    _username.dispose();
    _password.dispose();
    _url.dispose();
    _notes.dispose();
    _tags.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).width < 600;
    final fieldFill = theme.colorScheme.surfaceContainerLow;

    InputDecoration decoration(String label, IconData icon) {
      return InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: fieldFill,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
        ),
      );
    }

    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: compact
            ? const BorderRadius.vertical(top: Radius.circular(28))
            : BorderRadius.circular(28),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, compact ? 12 : 20, 20, 12),
          child: Column(
            children: [
              if (compact)
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.item == null ? '新建密码' : '编辑密码',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (compact)
                    IconButton(
                      tooltip: '关闭',
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.viewInsetsOf(context).bottom + 12,
                    ),
                    child: Column(
                      children: [
                        TextFormField(
                          key: const Key('item-title'),
                          controller: _title,
                          autofocus: !compact,
                          decoration: decoration('名称', Icons.label_outline),
                          validator: (value) =>
                              (value ?? '').trim().isEmpty ? '请输入名称' : null,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _username,
                          decoration: decoration('用户名', Icons.person_outline),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          key: const Key('item-password'),
                          controller: _password,
                          obscureText: _obscurePassword,
                          enableSuggestions: false,
                          autocorrect: false,
                          decoration: decoration('密码', Icons.key_outlined)
                              .copyWith(
                                suffixIcon: IconButton(
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _url,
                          keyboardType: TextInputType.url,
                          decoration: decoration('网站', Icons.link_outlined),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _notes,
                          minLines: 2,
                          maxLines: 4,
                          decoration: decoration('备注', Icons.notes_outlined),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _tags,
                          decoration: decoration(
                            '标签',
                            Icons.sell_outlined,
                          ).copyWith(hintText: '多个标签用逗号分隔'),
                        ),
                        const SizedBox(height: 4),
                        if (widget.viewModel.groups.isNotEmpty) ...[
                          _GroupSelector(
                            groups: widget.viewModel.groups,
                            selectedId: _groupId,
                            enabled: !_busy,
                            onSelected: (value) =>
                                setState(() => _groupId = value),
                          ),
                          const SizedBox(height: 10),
                        ],
                        Row(
                          children: [
                            Icon(
                              Icons.star_outline,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(child: Text('收藏此条目')),
                            Checkbox.adaptive(
                              value: _favorite,
                              splashRadius: 0,
                              overlayColor: const WidgetStatePropertyAll(
                                Colors.transparent,
                              ),
                              onChanged: _busy
                                  ? null
                                  : (value) => setState(
                                      () => _favorite = value ?? false,
                                    ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (widget.item != null)
                    TextButton(
                      onPressed: _busy ? null : _delete,
                      child: const Text('删除'),
                    ),
                  const Spacer(),
                  if (!compact)
                    TextButton(
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      child: const Text('取消'),
                    ),
                  if (compact)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : () => Navigator.pop(context),
                        child: const Text('取消'),
                      ),
                    ),
                  const SizedBox(width: 10),
                  if (compact)
                    Expanded(
                      child: FilledButton(
                        key: const Key('save-item'),
                        onPressed: _busy ? null : _save,
                        child: Text(_busy ? '保存中…' : '保存'),
                      ),
                    )
                  else
                    FilledButton(
                      key: const Key('save-item'),
                      onPressed: _busy ? null : _save,
                      child: Text(_busy ? '保存中…' : '保存'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    final saved = await widget.viewModel.saveItem(
      existing: widget.item,
      groupId: _groupId,
      title: _title.text,
      username: _username.text,
      password: _password.text,
      url: _url.text,
      notes: _notes.text,
      tags: _tags.text
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toSet()
          .toList(growable: false),
      favorite: _favorite,
    );
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context);
    } else {
      setState(() => _busy = false);
      _showError();
    }
  }

  Future<void> _delete() async {
    final item = widget.item;
    if (item == null) return;
    setState(() => _busy = true);
    final deleted = await widget.viewModel.deleteItem(item);
    if (!mounted) return;
    if (deleted) {
      Navigator.pop(context);
    } else {
      setState(() => _busy = false);
      _showError();
    }
  }

  void _showError() {
    showAppMessage(context, widget.viewModel.errorMessage ?? '操作失败，请重试');
  }
}

class _GroupSelector extends StatelessWidget {
  const _GroupSelector({
    required this.groups,
    required this.selectedId,
    required this.enabled,
    required this.onSelected,
  });

  final List<VaultGroup> groups;
  final String selectedId;
  final bool enabled;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = groups.firstWhere(
      (group) => group.id == selectedId,
      orElse: () => groups.first,
    );
    return GestureDetector(
      onTap: enabled
          ? () async {
              final value = await showModalBottomSheet<String>(
                context: context,
                showDragHandle: true,
                useSafeArea: true,
                builder: (context) => SafeArea(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 20),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                        child: Text(
                          '选择分组',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      ...groups.map(
                        (group) => ListTile(
                          leading: Icon(
                            group.id == selected.id
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            color: group.id == selected.id
                                ? theme.colorScheme.primary
                                : null,
                          ),
                          title: Text(group.name),
                          onTap: () => Navigator.pop(context, group.id),
                        ),
                      ),
                    ],
                  ),
                ),
              );
              if (value != null) onSelected(value);
            }
          : null,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.folder_outlined, size: 20),
            const SizedBox(width: 12),
            const Text('分组'),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                selected.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.expand_more),
          ],
        ),
      ),
    );
  }
}
