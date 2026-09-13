import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/services/native_autofill_service.dart';
import '../domain/models/vault_item.dart';
import '../domain/services/autofill_matcher.dart';
import '../ui/core/vault_brand.dart';
import '../ui/features/unlock/unlock_screen.dart';
import '../ui/features/vault/vault_view_model.dart';

class AutofillApp extends StatelessWidget {
  const AutofillApp({
    super.key,
    required this.vaultViewModel,
    required this.request,
  });

  final VaultViewModel vaultViewModel;
  final NativeAutofillRequest request;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: vaultViewModel,
      child: MaterialApp(
        title: '松匣自动填充',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF176B52)),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF72D7B2),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: _AutofillRouter(request: request),
      ),
    );
  }
}

class _AutofillRouter extends StatelessWidget {
  const _AutofillRouter({required this.request});

  final NativeAutofillRequest request;

  @override
  Widget build(BuildContext context) {
    return Consumer<VaultViewModel>(
      builder: (context, viewModel, _) => switch (viewModel.state) {
        VaultAppState.initializing => const _Message('正在读取密码库…', busy: true),
        VaultAppState.noVault ||
        VaultAppState.creating ||
        VaultAppState.restoring => const _Message('请先打开松匣并创建密码库'),
        VaultAppState.locked || VaultAppState.unlocking => UnlockScreen(
          busy: viewModel.state == VaultAppState.unlocking,
          errorMessage: viewModel.errorMessage,
          onUnlock: viewModel.unlock,
          deviceUnlockEnabled: viewModel.deviceUnlockEnabled,
          onDeviceUnlock: viewModel.unlockWithDevice,
          automaticDeviceUnlock: viewModel.automaticDeviceUnlock,
        ),
        VaultAppState.unlocked ||
        VaultAppState.saving ||
        VaultAppState.syncing => _AutofillPicker(request: request),
      },
    );
  }
}

class _AutofillPicker extends StatefulWidget {
  const _AutofillPicker({required this.request});

  final NativeAutofillRequest request;

  @override
  State<_AutofillPicker> createState() => _AutofillPickerState();
}

class _AutofillPickerState extends State<_AutofillPicker> {
  final _searchController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<VaultViewModel>();
    final allItems = [
      for (final item in viewModel.items)
        if (item.type == VaultItemType.login && item.password.isNotEmpty) item,
    ];
    final matched = matchingAutofillItems(
      items: allItems,
      domains: widget.request.webDomains,
      packageNames: widget.request.packageNames,
    );
    final query = _searchController.text.trim().toLowerCase();
    final source = query.isEmpty && matched.isNotEmpty ? matched : allItems;
    final items = source.where((item) {
      return query.isEmpty ||
          item.title.toLowerCase().contains(query) ||
          item.username.toLowerCase().contains(query) ||
          item.urls.any((url) => url.toLowerCase().contains(query));
    }).toList(growable: false);
    return Scaffold(
      appBar: AppBar(
        title: const VaultBrand(compact: true),
        actions: [
          IconButton(
            tooltip: '取消',
            onPressed: _submitting ? null : NativeAutofillAuth.cancel,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                enabled: !_submitting,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: '搜索名称、用户名或网站',
                  border: const OutlineInputBorder(),
                  errorText: _error,
                ),
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? const Center(child: Text('没有可填充的登录条目'))
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return ListTile(
                          enabled: !_submitting,
                          leading: CircleAvatar(
                            child: Text(
                              item.title.trim().isEmpty
                                  ? '?'
                                  : item.title.trim()[0].toUpperCase(),
                            ),
                          ),
                          title: Text(item.title),
                          subtitle: Text(
                            item.username,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _complete(item),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _complete(VaultItem item) async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await NativeAutofillAuth.complete(
        label: item.title,
        username: item.username,
        password: item.password,
      );
      if (mounted) context.read<VaultViewModel>().lock();
    } on PlatformException {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = '填充失败，请重试';
      });
    }
  }
}

class _Message extends StatelessWidget {
  const _Message(this.message, {this.busy = false});

  final String message;
  final bool busy;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const VaultBrand(compact: true)),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (busy) ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
          ],
          Text(message),
        ],
      ),
    ),
  );
}
