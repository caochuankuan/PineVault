part of 'vault_home_screen.dart';

Future<void> _showGroupManagement(
  BuildContext context,
  VaultViewModel viewModel,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _GroupManagementSheet(),
  );
}

class _GroupManagementSheet extends StatelessWidget {
  const _GroupManagementSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.78;
    final groups = context.watch<VaultViewModel>().groups;
    final sheetHeight = math.min(maxHeight, 148 + (groups.length + 1) * 88.0);
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 640, maxHeight: sheetHeight),
        child: Material(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: Consumer<VaultViewModel>(
              builder: (context, viewModel, _) {
                final groups = viewModel.groups;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 12, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '分组管理',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: '关闭',
                            onPressed: viewModel.busy
                                ? null
                                : () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '拖动右侧手柄调整顺序',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 0,
                        color: theme.colorScheme.surfaceContainerLow,
                        child: ListTile(
                          leading: Icon(
                            Icons.timer_outlined,
                            color: theme.colorScheme.primary,
                          ),
                          title: const Text('TOTP'),
                          subtitle: Text(
                            '系统分组 · ${viewModel.itemCountForGroup(VaultViewModel.totpGroupId)} 条记录',
                          ),
                          trailing: const Tooltip(
                            message: '系统分组不可编辑',
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: Icon(Icons.lock_outline),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ReorderableListView.builder(
                        buildDefaultDragHandles: false,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        itemCount: groups.length,
                        onReorder: viewModel.busy
                            ? (_, _) {}
                            : (oldIndex, newIndex) async {
                                if (oldIndex == 0 || newIndex == 0) return;
                                await viewModel.reorderGroups(
                                  oldIndex,
                                  newIndex,
                                );
                              },
                        itemBuilder: (context, index) {
                          final group = groups[index];
                          final isDefault = group.id == 'default';
                          return Card(
                            key: ValueKey(group.id),
                            margin: const EdgeInsets.only(bottom: 8),
                            elevation: 0,
                            color: theme.colorScheme.surfaceContainerLow,
                            child: ListTile(
                              leading: Icon(
                                isDefault
                                    ? Icons.folder_special_outlined
                                    : Icons.folder_outlined,
                                color: isDefault
                                    ? theme.colorScheme.primary
                                    : null,
                              ),
                              title: Text(
                                group.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${viewModel.itemCountForGroup(group.id)} 条记录',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: isDefault ? '默认分组不可重命名' : '重命名',
                                    onPressed: viewModel.busy || isDefault
                                        ? null
                                        : () => _renameGroup(
                                            context,
                                            viewModel,
                                            group,
                                          ),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                  IconButton(
                                    tooltip: isDefault ? '默认分组不可删除' : '删除',
                                    onPressed: viewModel.busy || isDefault
                                        ? null
                                        : () => _deleteGroup(
                                            context,
                                            viewModel,
                                            group,
                                          ),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                  ReorderableDragStartListener(
                                    index: index,
                                    enabled: !isDefault && !viewModel.busy,
                                    child: const Padding(
                                      padding: EdgeInsets.all(8),
                                      child: Icon(Icons.drag_handle),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: viewModel.busy
                              ? null
                              : () => _createGroup(context, viewModel),
                          icon: const Icon(Icons.add),
                          label: const Text('新建分组'),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _renameGroup(
  BuildContext context,
  VaultViewModel viewModel,
  VaultGroup group,
) async {
  final name = await _showGroupNameSheet(
    context,
    title: '重命名分组',
    initialName: group.name,
    actionLabel: '保存',
  );
  if (name == null || !context.mounted) return;
  final succeeded = await viewModel.renameGroup(group.id, name);
  if (context.mounted && succeeded) showAppMessage(context, '分组已重命名');
  if (context.mounted && !succeeded) {
    showAppMessage(context, viewModel.errorMessage ?? '重命名分组失败');
  }
}

Future<void> _deleteGroup(
  BuildContext context,
  VaultViewModel viewModel,
  VaultGroup group,
) async {
  final count = viewModel.itemCountForGroup(group.id);
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '删除分组',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              count == 0
                  ? '确定删除“${group.name}”吗？'
                  : '“${group.name}”中有 $count 条记录，删除后会移动到“未分组”，不会删除记录。',
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('删除'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  if (confirmed != true || !context.mounted) return;
  final succeeded = await viewModel.deleteGroup(group.id);
  if (context.mounted && succeeded) showAppMessage(context, '分组已删除');
  if (context.mounted && !succeeded) {
    showAppMessage(context, viewModel.errorMessage ?? '删除分组失败');
  }
}

Future<void> _createGroup(
  BuildContext context,
  VaultViewModel viewModel,
) async {
  final name = await _showGroupNameSheet(
    context,
    title: '新建分组',
    actionLabel: '创建',
  );
  if (name == null || !context.mounted) return;
  final created = await viewModel.createGroup(name);
  if (!context.mounted || created) return;
  showAppMessage(context, viewModel.errorMessage ?? '创建分组失败');
}

Future<String?> _showGroupNameSheet(
  BuildContext context, {
  required String title,
  String initialName = '',
  required String actionLabel,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _GroupNameSheet(
      title: title,
      initialName: initialName,
      actionLabel: actionLabel,
    ),
  );
}

class _GroupNameSheet extends StatefulWidget {
  const _GroupNameSheet({
    required this.title,
    required this.initialName,
    required this.actionLabel,
  });

  final String title;
  final String initialName;
  final String actionLabel;

  @override
  State<_GroupNameSheet> createState() => _GroupNameSheetState();
}

class _GroupNameSheetState extends State<_GroupNameSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  maxLength: 30,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: '分组名称',
                    prefixIcon: Icon(Icons.folder_outlined),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('取消'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _submit,
                        child: Text(widget.actionLabel),
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

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, name);
  }
}
