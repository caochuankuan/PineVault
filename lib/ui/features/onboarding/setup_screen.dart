import 'package:flutter/material.dart';

import '../../core/vault_brand.dart';
import 'restore_screen.dart';

typedef CreateVaultCallback = Future<void> Function(String masterPassword);

class SetupScreen extends StatefulWidget {
  const SetupScreen({
    super.key,
    required this.busy,
    required this.onCreate,
    required this.onRestore,
    this.errorMessage,
  });

  final bool busy;
  final String? errorMessage;
  final CreateVaultCallback onCreate;
  final RestoreVaultCallback onRestore;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Align(child: VaultBrand()),
                    const SizedBox(height: 40),
                    Text(
                      '创建本地密码库',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '主密码不会保存，也无法找回。请使用至少 8 个字符。',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      key: const Key('master-password'),
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      enableSuggestions: false,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: '主密码',
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
                        if ((value ?? '').length < 8) {
                          return '主密码至少需要 8 个字符';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('confirm-password'),
                      controller: _confirmationController,
                      obscureText: true,
                      enableSuggestions: false,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: '确认主密码',
                        prefixIcon: Icon(Icons.verified_user_outlined),
                      ),
                      validator: (value) {
                        if (value != _passwordController.text) {
                          return '两次输入的主密码不一致';
                        }
                        return null;
                      },
                    ),
                    if (widget.errorMessage case final message?) ...[
                      const SizedBox(height: 16),
                      Text(
                        message,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      key: const Key('create-vault'),
                      onPressed: widget.busy ? null : _submit,
                      icon: widget.busy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.lock_outline),
                      label: Text(widget.busy ? '正在创建…' : '创建密码库'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      key: const Key('open-restore'),
                      onPressed: widget.busy ? null : _openRestore,
                      icon: const Icon(Icons.cloud_download_outlined),
                      label: const Text('从坚果云恢复'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await widget.onCreate(_passwordController.text);
  }

  Future<void> _openRestore() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => RestoreScreen(onRestore: widget.onRestore),
      ),
    );
  }
}
