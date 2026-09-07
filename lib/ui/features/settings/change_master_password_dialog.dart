import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../vault/vault_view_model.dart';

class ChangeMasterPasswordDialog extends StatefulWidget {
  const ChangeMasterPasswordDialog({super.key});

  @override
  State<ChangeMasterPasswordDialog> createState() =>
      _ChangeMasterPasswordDialogState();
}

class _ChangeMasterPasswordDialogState
    extends State<ChangeMasterPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return AlertDialog(
      title: const Text('修改主密码'),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 520, maxHeight: height * 0.55),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('修改后会立即重包密码库密钥，并尝试同步到坚果云。其他设备下次解锁需使用新主密码。'),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('current-master-password'),
                  controller: _current,
                  obscureText: true,
                  enabled: !_busy,
                  decoration: const InputDecoration(labelText: '当前主密码'),
                  validator: (value) =>
                      (value ?? '').isEmpty ? '请输入当前主密码' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('new-master-password'),
                  controller: _next,
                  obscureText: true,
                  enabled: !_busy,
                  decoration: const InputDecoration(labelText: '新主密码'),
                  validator: (value) =>
                      (value ?? '').length < 8 ? '新主密码至少需要 8 个字符' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('confirm-new-master-password'),
                  controller: _confirm,
                  obscureText: true,
                  enabled: !_busy,
                  decoration: const InputDecoration(labelText: '确认新主密码'),
                  validator: (value) =>
                      value != _next.text ? '两次输入的新主密码不一致' : null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const Key('change-master-password'),
          onPressed: _busy ? null : _submit,
          child: Text(_busy ? '正在修改…' : '确认修改'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    final viewModel = context.read<VaultViewModel>();
    final succeeded = await viewModel.changeMasterPassword(
      currentPassword: _current.text,
      newPassword: _next.text,
    );
    if (!mounted) return;
    if (succeeded) {
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('主密码已修改')));
    } else {
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(viewModel.errorMessage ?? '修改失败')));
    }
  }
}
