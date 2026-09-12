part of 'vault_home_screen.dart';

enum _ViewerAction { edit }

class _ItemViewer extends StatefulWidget {
  const _ItemViewer({
    super.key,
    required this.viewModel,
    required this.item,
    this.onClose,
    this.onEdit,
    this.onDeleted,
  });

  final VaultViewModel viewModel;
  final VaultItem item;
  final VoidCallback? onClose;
  final VoidCallback? onEdit;
  final VoidCallback? onDeleted;

  @override
  State<_ItemViewer> createState() => _ItemViewerState();
}

class _ItemViewerState extends State<_ItemViewer> {
  bool _obscurePassword = true;
  bool _busy = false;
  OverlayEntry? _toastEntry;

  @override
  void dispose() {
    _toastEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).width < 600;

    Widget valueRow(
      String label,
      String value,
      IconData icon, {
      VoidCallback? onTap,
      VoidCallback? onCopy,
      VoidCallback? onOpen,
    }) {
      final content = Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(label, style: theme.textTheme.labelMedium),
                          if (onCopy != null)
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 28,
                                minHeight: 28,
                              ),
                              style: IconButton.styleFrom(
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              tooltip: '复制$label',
                              onPressed: onCopy,
                              icon: const Icon(Icons.copy_outlined, size: 17),
                            ),
                          if (onOpen != null)
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 28,
                                minHeight: 28,
                              ),
                              style: IconButton.styleFrom(
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              tooltip: '打开$label',
                              onPressed: onOpen,
                              icon: const Icon(
                                Icons.open_in_new_outlined,
                                size: 17,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      SelectableText(
                        value.isEmpty ? '未设置' : value,
                        style: theme.textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return onTap == null
          ? content
          : GestureDetector(onTap: onTap, child: content);
    }

    final password = _obscurePassword
        ? ('•' * widget.item.password.length)
        : widget.item.password;

    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: compact
            ? const BorderRadius.vertical(top: Radius.circular(28))
            : BorderRadius.circular(28),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, compact ? 12 : 20, 20, 12),
          child: Column(
            mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
            children: [
              if (compact)
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
                  CircleAvatar(
                    child: Text(
                      widget.item.title.isEmpty
                          ? '?'
                          : widget.item.title[0].toUpperCase(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.item.title,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.item.favorite)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Icon(Icons.star, color: Colors.amber),
                          ),
                      ],
                    ),
                  ),
                  if (compact)
                    IconButton(
                      tooltip: '关闭',
                      onPressed: _busy ? null : _close,
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                fit: compact ? FlexFit.loose : FlexFit.tight,
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.viewInsetsOf(context).bottom + 8,
                  ),
                  child: Column(
                    children: [
                      valueRow(
                        '用户名',
                        widget.item.username,
                        Icons.person_outline,
                        onTap: widget.item.username.isEmpty
                            ? null
                            : () => _copy(widget.item.username, '用户名'),
                        onCopy: widget.item.username.isEmpty
                            ? null
                            : () => _copy(widget.item.username, '用户名'),
                      ),
                      GestureDetector(
                        onTap: widget.item.password.isEmpty
                            ? null
                            : () => _copy(widget.item.password, '密码'),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 13,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.key_outlined,
                                    size: 20,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              '密码',
                                              style:
                                                  theme.textTheme.labelMedium,
                                            ),
                                            if (widget.item.password.isNotEmpty)
                                              IconButton(
                                                visualDensity:
                                                    VisualDensity.compact,
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(
                                                      minWidth: 32,
                                                      minHeight: 28,
                                                    ),
                                                tooltip: '复制密码',
                                                onPressed: () => _copy(
                                                  widget.item.password,
                                                  '密码',
                                                ),
                                                icon: const Icon(
                                                  Icons.copy_outlined,
                                                  size: 17,
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        SelectableText(
                                          password,
                                          style: theme.textTheme.bodyLarge,
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: _obscurePassword ? '显示密码' : '隐藏密码',
                                    onPressed: () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (widget.item.totp case final totp?)
                        _TotpViewerCard(
                          config: totp,
                          onCopy: (code) => _copy(code, '动态验证码'),
                        ),
                      valueRow(
                        '网站',
                        widget.item.urls.isEmpty ? '' : widget.item.urls.first,
                        Icons.link_outlined,
                        onTap: widget.item.urls.isEmpty
                            ? null
                            : () => _openWebsite(widget.item.urls.first),
                        onCopy: widget.item.urls.isEmpty
                            ? null
                            : () => _copy(widget.item.urls.first, '网站'),
                        onOpen: widget.item.urls.isEmpty
                            ? null
                            : () => _openWebsite(widget.item.urls.first),
                      ),
                      if (widget.item.notes.isNotEmpty)
                        valueRow(
                          '备注',
                          widget.item.notes,
                          Icons.notes_outlined,
                          onCopy: () => _copy(widget.item.notes, '备注'),
                        ),
                      if (widget.item.tags.isNotEmpty)
                        valueRow(
                          '标签',
                          widget.item.tags.join(' · '),
                          Icons.sell_outlined,
                          onCopy: () =>
                              _copy(widget.item.tags.join(', '), '标签'),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (compact)
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                        onPressed: _busy ? null : _delete,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('删除', softWrap: false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                        onPressed: _busy ? null : () => Navigator.pop(context),
                        child: const Text('关闭', softWrap: false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                        onPressed: _busy ? null : _edit,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('编辑', softWrap: false),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: _busy ? null : _delete,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('删除'),
                    ),
                    const Spacer(),
                    OutlinedButton(
                      onPressed: _busy ? null : _close,
                      child: const Text('关闭'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: _busy ? null : _edit,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('编辑'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _edit() {
    final onEdit = widget.onEdit;
    if (onEdit != null) {
      onEdit();
      return;
    }
    Navigator.pop(context, _ViewerAction.edit);
  }

  void _close() {
    final onClose = widget.onClose;
    if (onClose != null) {
      onClose();
      return;
    }
    Navigator.pop(context);
  }

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    _showToast('$label已复制');
  }

  Future<void> _openWebsite(String value) async {
    final trimmed = value.trim();
    final normalized = trimmed.contains('://') ? trimmed : 'https://$trimmed';
    final uri = Uri.tryParse(normalized);
    if (uri == null || uri.host.isEmpty) {
      if (mounted) _showToast('网站地址无效');
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      _showToast('无法打开网站');
    }
  }

  void _showToast(String message) {
    _toastEntry?.remove();
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        left: 24,
        right: 24,
        bottom: 92,
        child: IgnorePointer(
          child: Center(
            child: Material(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    _toastEntry = entry;
    Overlay.of(context).insert(entry);
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (_toastEntry == entry) {
        entry.remove();
        _toastEntry = null;
      }
    });
  }

  Future<void> _delete() async {
    setState(() => _busy = true);
    final deleted = await widget.viewModel.deleteItem(widget.item);
    if (!mounted) return;
    if (deleted) {
      final onDeleted = widget.onDeleted;
      if (onDeleted != null) {
        onDeleted();
      } else {
        Navigator.pop(context);
      }
    } else {
      setState(() => _busy = false);
      showAppMessage(context, widget.viewModel.errorMessage ?? '删除失败，请重试');
    }
  }
}

class _TotpViewerCard extends StatefulWidget {
  const _TotpViewerCard({required this.config, required this.onCopy});

  final TotpConfig config;
  final ValueChanged<String> onCopy;

  @override
  State<_TotpViewerCard> createState() => _TotpViewerCardState();
}

class _TotpViewerCardState extends State<_TotpViewerCard> {
  static const _service = TotpService();
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
    final code = _service.generate(widget.config, time: _now);
    final remaining = _service.remainingSeconds(widget.config, time: _now);
    final split = code.length ~/ 2;
    final displayCode = '${code.substring(0, split)} ${code.substring(split)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Icon(
                Icons.timer_outlined,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('动态验证码', style: theme.textTheme.labelMedium),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 28,
                          ),
                          tooltip: '复制动态验证码',
                          onPressed: () => widget.onCopy(code),
                          icon: const Icon(Icons.copy_outlined, size: 17),
                        ),
                      ],
                    ),
                    SelectableText(
                      displayCode,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: remaining / widget.config.period,
                            minHeight: 4,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text('$remaining 秒'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
