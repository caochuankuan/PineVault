part of 'vault_home_screen.dart';

enum _ItemAction { all, username, password, totp, website, notes, openWebsite }

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
          if (item.totp != null)
            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: const Text('复制动态验证码'),
              onTap: () => Navigator.pop(context, _ItemAction.totp),
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
    case _ItemAction.totp:
      await _copyItemText(
        context,
        const TotpService().generate(item.totp!),
        '动态验证码',
      );
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
