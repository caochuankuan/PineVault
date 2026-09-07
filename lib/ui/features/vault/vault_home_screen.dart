import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/models/vault_item.dart';
import '../../core/vault_brand.dart';
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
          if (viewModel.state == VaultAppState.saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          IconButton(
            tooltip: 'WebDAV 设置',
            onPressed:
                viewModel.state == VaultAppState.saving ||
                    viewModel.vaultId == null
                ? null
                : () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          WebDavSettingsScreen(vaultId: viewModel.vaultId!),
                    ),
                  ),
            icon: const Icon(Icons.cloud_sync_outlined),
          ),
          IconButton(
            tooltip: '锁定',
            onPressed: viewModel.state == VaultAppState.saving
                ? null
                : viewModel.lock,
            icon: const Icon(Icons.lock_outline),
          ),
        ],
      ),
      body: LayoutBuilder(
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
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add-item'),
        onPressed: viewModel.state == VaultAppState.saving
            ? null
            : () => _openEditor(context, viewModel),
        icon: const Icon(Icons.add),
        label: const Text('新建'),
      ),
    );
  }
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
          child: SearchBar(
            hintText: '搜索名称、用户名或网站',
            leading: const Icon(Icons.search),
            onChanged: viewModel.setQuery,
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
                      onTap: () => _openEditor(context, viewModel, item),
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
  await showDialog<void>(
    context: context,
    builder: (context) => _ItemEditorDialog(viewModel: viewModel, item: item),
  );
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
    return AlertDialog(
      title: Text(widget.item == null ? '新建密码' : '编辑密码'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: const Key('item-title'),
                  controller: _title,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: '名称'),
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? '请输入名称' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _username,
                  decoration: const InputDecoration(labelText: '用户名'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('item-password'),
                  controller: _password,
                  obscureText: _obscurePassword,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: '密码',
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _url,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(labelText: '网站'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notes,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: '备注'),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _favorite,
                  title: const Text('收藏'),
                  onChanged: (value) =>
                      setState(() => _favorite = value ?? false),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        if (widget.item != null)
          TextButton(
            onPressed: _busy ? null : _delete,
            child: const Text('删除'),
          ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const Key('save-item'),
          onPressed: _busy ? null : _save,
          child: Text(_busy ? '保存中…' : '保存'),
        ),
      ],
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
