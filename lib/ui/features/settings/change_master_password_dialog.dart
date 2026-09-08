import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_feedback.dart';
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
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: height * 0.9),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Column(
              children: [
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
                        '修改主密码',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭',
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          const Text(
                            '修改后会立即重包密码库密钥，并尝试同步到坚果云。其他设备下次解锁需使用新主密码。',
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            key: const Key('current-master-password'),
                            controller: _current,
                            obscureText: true,
                            enabled: !_busy,
                            decoration: const InputDecoration(
                              labelText: '当前主密码',
                            ),
                            validator: (value) =>
                                (value ?? '').isEmpty ? '请输入当前主密码' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            key: const Key('new-master-password'),
                            controller: _next,
                            obscureText: true,
                            enabled: !_busy,
                            decoration: const InputDecoration(
                              labelText: '新主密码',
                            ),
                            validator: (value) => (value ?? '').length < 8
                                ? '新主密码至少需要 8 个字符'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            key: const Key('confirm-new-master-password'),
                            controller: _confirm,
                            obscureText: true,
                            enabled: !_busy,
                            decoration: const InputDecoration(
                              labelText: '确认新主密码',
                            ),
                            validator: (value) =>
                                value != _next.text ? '两次输入的新主密码不一致' : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : () => Navigator.pop(context),
                        child: const Text('取消'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        key: const Key('change-master-password'),
                        onPressed: _busy ? null : _submit,
                        child: Text(_busy ? '正在修改…' : '确认修改'),
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
      showAppMessage(context, '主密码已修改');
    } else {
      setState(() => _busy = false);
      showAppMessage(context, viewModel.errorMessage ?? '修改失败');
    }
  }
}
