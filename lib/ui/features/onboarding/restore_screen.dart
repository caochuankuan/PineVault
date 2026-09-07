import 'package:flutter/material.dart';

typedef RestoreVaultCallback =
    Future<String?> Function({
      required String serverUrl,
      required String username,
      required String applicationPassword,
      required String masterPassword,
    });

class RestoreScreen extends StatefulWidget {
  const RestoreScreen({super.key, required this.onRestore});

  final RestoreVaultCallback onRestore;

  @override
  State<RestoreScreen> createState() => _RestoreScreenState();
}

class _RestoreScreenState extends State<RestoreScreen> {
  final _formKey = GlobalKey<FormState>();
  final _server = TextEditingController(
    text: 'https://dav.jianguoyun.com/dav/',
  );
  final _username = TextEditingController();
  final _applicationPassword = TextEditingController();
  final _masterPassword = TextEditingController();
  bool _busy = false;
  bool _showApplicationPassword = false;
  bool _showMasterPassword = false;
  String? _errorMessage;

  @override
  void dispose() {
    _server.dispose();
    _username.dispose();
    _applicationPassword.dispose();
    _masterPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('从坚果云恢复')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '恢复已有密码库',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '应用会先下载密文并验证主密码，验证成功后才保存到本机。'
                      '坚果云配置会随密码库一起加密。',
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      key: const Key('restore-server'),
                      controller: _server,
                      enabled: !_busy,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'WebDAV 地址',
                        prefixIcon: Icon(Icons.cloud_outlined),
                      ),
                      validator: _required('请输入 WebDAV 地址'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('restore-username'),
                      controller: _username,
                      enabled: !_busy,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.username],
                      decoration: const InputDecoration(
                        labelText: '坚果云账号',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: _required('请输入坚果云账号'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('restore-application-password'),
                      controller: _applicationPassword,
                      enabled: !_busy,
                      obscureText: !_showApplicationPassword,
                      enableSuggestions: false,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: '坚果云第三方应用密码',
                        prefixIcon: const Icon(Icons.password_outlined),
                        suffixIcon: IconButton(
                          onPressed: _busy
                              ? null
                              : () => setState(
                                  () => _showApplicationPassword =
                                      !_showApplicationPassword,
                                ),
                          icon: Icon(
                            _showApplicationPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                      validator: _required('请输入第三方应用密码'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('restore-master-password'),
                      controller: _masterPassword,
                      enabled: !_busy,
                      obscureText: !_showMasterPassword,
                      enableSuggestions: false,
                      autocorrect: false,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: '原密码库主密码',
                        prefixIcon: const Icon(Icons.key_outlined),
                        suffixIcon: IconButton(
                          onPressed: _busy
                              ? null
                              : () => setState(
                                  () => _showMasterPassword =
                                      !_showMasterPassword,
                                ),
                          icon: Icon(
                            _showMasterPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                      validator: _required('请输入原主密码'),
                    ),
                    if (_errorMessage case final message?) ...[
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
                      key: const Key('restore-vault'),
                      onPressed: _busy ? null : _submit,
                      icon: _busy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_download_outlined),
                      label: Text(_busy ? '正在验证并恢复…' : '下载并恢复'),
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

  FormFieldValidator<String> _required(String message) =>
      (value) => (value ?? '').trim().isEmpty ? message : null;

  Future<void> _submit() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    final error = await widget.onRestore(
      serverUrl: _server.text,
      username: _username.text,
      applicationPassword: _applicationPassword.text,
      masterPassword: _masterPassword.text,
    );
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context);
    } else {
      setState(() {
        _busy = false;
        _errorMessage = error;
      });
    }
  }
}
