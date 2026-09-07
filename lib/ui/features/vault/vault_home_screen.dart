import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/models/vault_item.dart';
import '../../core/vault_brand.dart';
import '../settings/change_master_password_dialog.dart';
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
          IconButton(
            tooltip: '立即同步',
            onPressed: viewModel.busy ? null : () => _sync(context, viewModel),
            icon: const Icon(Icons.sync),
          ),
          IconButton(
            tooltip: 'WebDAV 设置',
            onPressed: viewModel.busy
                ? null
                : () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const WebDavSettingsScreen(),
                    ),
                  ),
            icon: const Icon(Icons.cloud_sync_outlined),
          ),
          PopupMenuButton<_VaultMenuAction>(
            onSelected: (action) => _handleMenu(context, action),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _VaultMenuAction.history,
                child: ListTile(
                  leading: Icon(Icons.history),
                  title: Text('同步历史'),
                ),
              ),
              PopupMenuItem(
                value: _VaultMenuAction.changeMasterPassword,
                child: ListTile(
                  leading: Icon(Icons.key_outlined),
                  title: Text('修改主密码'),
                ),
              ),
            ],
          ),
          IconButton(
            tooltip: '锁定',
            onPressed: viewModel.busy ? null : viewModel.lock,
            icon: const Icon(Icons.lock_outline),
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
      floatingActionButton: FloatingActionButton.extended(
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

enum _VaultMenuAction { history, changeMasterPassword }

Future<void> _handleMenu(BuildContext context, _VaultMenuAction action) async {
  switch (action) {
    case _VaultMenuAction.history:
      await Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (_) => const SyncHistoryScreen()),
      );
    case _VaultMenuAction.changeMasterPassword:
      await showDialog<void>(
        context: context,
        builder: (_) => const ChangeMasterPasswordDialog(),
      );
  }
}

Future<void> _sync(BuildContext context, VaultViewModel viewModel) async {
  final succeeded = await viewModel.sync();
  if (!context.mounted) return;
  final message = succeeded ? viewModel.syncMessage : viewModel.errorMessage;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message ?? '同步失败，请重试')));
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
        Expanded(
          child: items.isEmpty
              ? _EmptyVault(hasQuery: viewModel.query.isNotEmpty)
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          item.title.isEmpty
                              ? '?'
                              : item.title[0].toUpperCase(),
                        ),
                      ),
                      title: Text(item.title),
                      subtitle: Text(
                        item.username.isEmpty ? '未设置用户名' : item.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: item.favorite
                          ? const Icon(Icons.star, color: Colors.amber)
                          : null,
                      onTap: () => _openViewer(context, viewModel, item),
                    );
                  },
                ),
        ),
      ],
    );
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
      builder: (_) => _ItemViewer(viewModel: viewModel, item: item),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).width < 600;

    Widget valueRow(String label, String value, IconData icon) {
      return Padding(
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
                      Text(label, style: theme.textTheme.labelMedium),
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
                  if (compact)
                    IconButton(
                      tooltip: '关闭',
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
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
                      ),
                      Padding(
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
                                      Text(
                                        '密码',
                                        style: theme.textTheme.labelMedium,
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
                                    () => _obscurePassword = !_obscurePassword,
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
                      valueRow(
                        '网站',
                        widget.item.urls.isEmpty ? '' : widget.item.urls.first,
                        Icons.link_outlined,
                      ),
                      if (widget.item.notes.isNotEmpty)
                        valueRow('备注', widget.item.notes, Icons.notes_outlined),
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

  Future<void> _delete() async {
    setState(() => _busy = true);
    final deleted = await widget.viewModel.deleteItem(widget.item);
    if (!mounted) return;
    if (deleted) {
      Navigator.pop(context);
    } else {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.viewModel.errorMessage ?? '删除失败，请重试')),
      );
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
  late bool _favorite;
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
    _favorite = item?.favorite ?? false;
  }

  @override
  void dispose() {
    _title.dispose();
    _username.dispose();
    _password.dispose();
    _url.dispose();
    _notes.dispose();
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
                        const SizedBox(height: 4),
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
      title: _title.text,
      username: _username.text,
      password: _password.text,
      url: _url.text,
      notes: _notes.text,
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(widget.viewModel.errorMessage ?? '操作失败，请重试')),
    );
  }
}
