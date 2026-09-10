part of 'vault_home_screen.dart';

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
        if (viewModel.selectionMode)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Text('已选择 ${viewModel.selectedItemIds.length} 项'),
                const Spacer(),
                TextButton(
                  onPressed: viewModel.items.isEmpty
                      ? null
                      : viewModel.selectAllItems,
                  child: const Text('全选'),
                ),
                TextButton(
                  onPressed: viewModel.clearItemSelection,
                  child: const Text('清除'),
                ),
                IconButton(
                  tooltip: '退出多选',
                  onPressed: viewModel.exitSelectionMode,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 16, right: 8, bottom: 8),
            children: [
              FilterChip(
                label: const Text('全部'),
                selected: viewModel.selectedGroupId == 'all',
                onSelected: (_) => viewModel.setSelectedGroup('all'),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: FilterChip(
                  label: const Text('TOTP'),
                  selected:
                      viewModel.selectedGroupId == VaultViewModel.totpGroupId,
                  onSelected: (_) =>
                      viewModel.setSelectedGroup(VaultViewModel.totpGroupId),
                ),
              ),
              ...viewModel.groups.map(
                (group) => Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: FilterChip(
                    label: Text(group.name),
                    selected: viewModel.selectedGroupId == group.id,
                    onSelected: (_) => viewModel.setSelectedGroup(group.id),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: const Text('新建分组'),
                  onPressed: viewModel.busy
                      ? null
                      : () => _createGroup(context, viewModel),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? _EmptyVault(hasQuery: viewModel.query.isNotEmpty)
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final details = <String>[
                      item.username.isEmpty ? '未设置用户名' : item.username,
                      if (viewModel.showWebsites && item.urls.isNotEmpty)
                        item.urls.first,
                      if (viewModel.showPasswords)
                        item.password.isEmpty ? '未设置密码' : item.password,
                    ].join(' · ');
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      elevation: 0,
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: viewModel.selectionMode
                            ? () => viewModel.toggleItemSelection(item.id)
                            : () => _openViewer(context, viewModel, item),
                        onLongPress: viewModel.selectionMode
                            ? null
                            : () => _showItemActions(context, item),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              if (viewModel.selectionMode)
                                Padding(
                                  padding: const EdgeInsets.only(right: 2),
                                  child: Checkbox(
                                    value: viewModel.selectedItemIds.contains(
                                      item.id,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    onChanged: (_) =>
                                        viewModel.toggleItemSelection(item.id),
                                  ),
                                )
                              else
                                CircleAvatar(
                                  child: Text(
                                    item.title.isEmpty
                                        ? '?'
                                        : item.title[0].toUpperCase(),
                                  ),
                                ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      details,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (viewModel.shouldShowTotp &&
                                        item.totp != null) ...[
                                      const SizedBox(height: 7),
                                      _HomeTotpLine(config: item.totp!),
                                    ],
                                  ],
                                ),
                              ),
                              if (item.favorite)
                                const Padding(
                                  padding: EdgeInsets.only(left: 8),
                                  child: Icon(Icons.star, color: Colors.amber),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (viewModel.selectionMode && viewModel.selectedItemIds.isNotEmpty)
          _BatchActionBar(viewModel: viewModel),
      ],
    );
  }
}

class _HomeTotpLine extends StatefulWidget {
  const _HomeTotpLine({required this.config});

  final TotpConfig config;

  @override
  State<_HomeTotpLine> createState() => _HomeTotpLineState();
}

class _HomeTotpLineState extends State<_HomeTotpLine> {
  static const _totpService = TotpService();
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final code = _totpService.generate(widget.config, time: _now);
    final remaining = _totpService.remainingSeconds(widget.config, time: _now);
    final split = code.length ~/ 2;
    final displayCode = '${code.substring(0, split)} ${code.substring(split)}';
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 4, 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            Icons.timer_outlined,
            size: 16,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            displayCode,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: LinearProgressIndicator(
              value: remaining / widget.config.period,
              minHeight: 3,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 7),
          Text('$remaining 秒', style: theme.textTheme.labelSmall),
          IconButton(
            tooltip: '复制动态验证码',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 28),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (context.mounted) showAppMessage(context, '动态验证码已复制');
            },
            icon: const Icon(Icons.copy_outlined, size: 16),
          ),
        ],
      ),
    );
  }
}

class _BatchActionBar extends StatelessWidget {
  const _BatchActionBar({required this.viewModel});

  final VaultViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              tooltip: '收藏/取消收藏',
              onPressed: viewModel.busy ? null : () => _toggleFavorite(context),
              icon: const Icon(Icons.star_outline),
            ),
            IconButton(
              tooltip: '移动分组',
              onPressed: viewModel.busy ? null : () => _moveGroup(context),
              icon: const Icon(Icons.drive_file_move_outlined),
            ),
            IconButton(
              tooltip: '复制全部',
              onPressed: () => _copyAll(context),
              icon: const Icon(Icons.copy_all_outlined),
            ),
            IconButton(
              tooltip: '删除',
              onPressed: viewModel.busy ? null : () => _delete(context),
              icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleFavorite(BuildContext context) async {
    final allFavorite = viewModel.selectedItems.every((item) => item.favorite);
    final ok = await viewModel.batchSetFavorite(!allFavorite);
    if (context.mounted && ok) {
      _showMessage(context, allFavorite ? '已取消收藏' : '已收藏');
    }
  }

  Future<void> _moveGroup(BuildContext context) async {
    final groupId = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 12),
          children: [
            const ListTile(title: Text('移动到分组')),
            for (final group in viewModel.groups)
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(group.name),
                onTap: () => Navigator.pop(context, group.id),
              ),
          ],
        ),
      ),
    );
    if (groupId == null || !context.mounted) return;
    final ok = await viewModel.batchMoveToGroup(groupId);
    if (context.mounted && ok) _showMessage(context, '已移动到分组');
  }

  Future<void> _copyAll(BuildContext context) async {
    final selectedItems = viewModel.selectedItems;
    final selectedCount = selectedItems.length;
    final text = selectedItems
        .map(
          (item) => [
            '名称：${item.title}',
            '账号：${item.username}',
            '密码：${item.password}',
            '网站：${item.urls.isEmpty ? '' : item.urls.first}',
            '备注：${item.notes}',
            if (item.tags.isNotEmpty) '标签：${item.tags.join(', ')}',
          ].join('\n'),
        )
        .join('\n\n');
    await Clipboard.setData(ClipboardData(text: text));
    viewModel.exitSelectionMode();
    if (context.mounted) {
      _showMessage(context, '已复制 $selectedCount 条记录');
    }
  }

  Future<void> _delete(BuildContext context) async {
    final count = viewModel.selectedItemIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除 $count 条记录？'),
        content: const Text('删除后会自动同步到其他设备。'),
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
    if (confirmed != true || !context.mounted) return;
    final ok = await viewModel.batchDelete();
    if (context.mounted && ok) _showMessage(context, '已删除 $count 条记录');
  }
}
