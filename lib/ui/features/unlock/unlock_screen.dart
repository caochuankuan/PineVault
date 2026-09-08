import 'package:flutter/material.dart';

import '../../core/vault_brand.dart';

typedef UnlockVaultCallback = Future<void> Function(String masterPassword);

class UnlockScreen extends StatefulWidget {
  const UnlockScreen({
    super.key,
    required this.busy,
    required this.onUnlock,
    required this.deviceUnlockEnabled,
    required this.onDeviceUnlock,
    this.errorMessage,
  });

  final bool busy;
  final String? errorMessage;
  final UnlockVaultCallback onUnlock;
  final bool deviceUnlockEnabled;
  final Future<void> Function() onDeviceUnlock;

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _autoUnlockRequested = false;

  @override
  void initState() {
    super.initState();
    _requestAutomaticDeviceUnlock();
  }

  @override
  void didUpdateWidget(UnlockScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.deviceUnlockEnabled && widget.deviceUnlockEnabled) {
      _requestAutomaticDeviceUnlock();
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
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
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Align(child: VaultBrand()),
                    const SizedBox(height: 40),
                    Text(
                      '解锁密码库',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      key: const Key('unlock-password'),
                      controller: _passwordController,
                      autofocus: true,
                      obscureText: _obscurePassword,
                      enableSuggestions: false,
                      autocorrect: false,
                      onFieldSubmitted: (_) => _submit(),
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
                      validator: (value) =>
                          (value ?? '').isEmpty ? '请输入主密码' : null,
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
                      key: const Key('unlock-vault'),
                      onPressed: widget.busy ? null : _submit,
                      icon: widget.busy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.lock_open_outlined),
                      label: Text(widget.busy ? '正在解锁…' : '解锁'),
                    ),
                    if (widget.deviceUnlockEnabled) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        key: const Key('device-unlock-vault'),
                        onPressed: widget.busy ? null : widget.onDeviceUnlock,
                        icon: const Icon(Icons.fingerprint),
                        label: const Text('使用设备验证解锁'),
                      ),
                    ],
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
    if (widget.busy || !(_formKey.currentState?.validate() ?? false)) return;
    await widget.onUnlock(_passwordController.text);
  }

  void _requestAutomaticDeviceUnlock() {
    if (_autoUnlockRequested || !widget.deviceUnlockEnabled) return;
    _autoUnlockRequested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !widget.busy) widget.onDeviceUnlock();
    });
  }
}
