import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_feedback.dart';
import 'webdav_settings_view_model.dart';

class WebDavSettingsScreen extends StatefulWidget {
  const WebDavSettingsScreen({super.key});

  @override
  State<WebDavSettingsScreen> createState() => _WebDavSettingsScreenState();
}

class _WebDavSettingsScreenState extends State<WebDavSettingsScreen> {
  static const _defaultServerUrl = 'https://dav.jianguoyun.com/dav/';

  final _formKey = GlobalKey<FormState>();
  final _serverController = TextEditingController(text: _defaultServerUrl);
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _loadedValues = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final viewModel = context.read<WebDavSettingsViewModel>();
    await viewModel.load();
    if (!mounted) return;
    final configuration = viewModel.configuration;
    if (configuration != null) {
      _serverController.text = configuration.serverUrl;
      _usernameController.text = configuration.username;
    }
    setState(() => _loadedValues = true);
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<WebDavSettingsViewModel>();
    final configuration = viewModel.configuration;
    return Scaffold(
      appBar: AppBar(title: const Text('坚果云 WebDAV')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '同步配置',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '请使用坚果云账号和“第三方应用管理”中生成的应用密码。'
                      '连接成功后，配置会写入主密码加密的密码库。',
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      key: const Key('webdav-server'),
                      controller: _serverController,
                      enabled: !viewModel.busy,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'WebDAV 地址',
                        prefixIcon: Icon(Icons.cloud_outlined),
                      ),
                      validator: (value) =>
                          (value ?? '').trim().isEmpty ? '请输入 WebDAV 地址' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('webdav-username'),
                      controller: _usernameController,
                      enabled: !viewModel.busy,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.username],
                      decoration: const InputDecoration(
                        labelText: '坚果云账号',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) =>
                          (value ?? '').trim().isEmpty ? '请输入坚果云账号' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('webdav-password'),
                      controller: _passwordController,
                      enabled: !viewModel.busy,
                      obscureText: _obscurePassword,
                      enableSuggestions: false,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: '第三方应用密码',
                        helperText: configuration?.hasPassword == true
                            ? '已安全保存；留空则继续使用原密码'
                            : null,
                        prefixIcon: const Icon(Icons.password_outlined),
                        suffixIcon: IconButton(
                          onPressed: viewModel.busy
                              ? null
                              : () => setState(
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
                        if ((value ?? '').isEmpty &&
                            configuration?.hasPassword != true) {
                          return '请输入第三方应用密码';
                        }
                        return null;
                      },
                    ),
                    if (viewModel.errorMessage case final message?) ...[
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
                      key: const Key('test-save-webdav'),
                      onPressed: viewModel.busy || !_loadedValues
                          ? null
                          : _testAndSave,
                      icon: viewModel.state == WebDavSettingsState.testing
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_done_outlined),
                      label: Text(
                        viewModel.state == WebDavSettingsState.testing
                            ? '正在测试…'
                            : '测试连接并保存',
                      ),
                    ),
                    if (configuration != null) ...[
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: viewModel.busy ? null : _confirmClear,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('删除 WebDAV 配置'),
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

  Future<void> _testAndSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final succeeded = await context.read<WebDavSettingsViewModel>().testAndSave(
      serverUrl: _serverController.text,
      username: _usernameController.text,
      password: _passwordController.text,
    );
    if (!mounted || !succeeded) return;
    _passwordController.clear();
    showAppMessage(context, '连接成功，配置已安全保存');
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除 WebDAV 配置？'),
        content: const Text('服务器地址、账号和应用密码将从当前加密密码库中删除。'),
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
    if (confirmed != true || !mounted) return;
    final cleared = await context.read<WebDavSettingsViewModel>().clear();
    if (!mounted || !cleared) return;
    _serverController.text = _defaultServerUrl;
    _usernameController.clear();
    _passwordController.clear();
    showAppMessage(context, 'WebDAV 配置已删除');
  }
}
