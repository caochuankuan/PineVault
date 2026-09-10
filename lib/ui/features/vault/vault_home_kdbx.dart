part of 'vault_home_screen.dart';

Future<void> _importKdbx(BuildContext context, VaultViewModel viewModel) async {
  PlatformFile? file;
  try {
    file = await FilePicker.pickFile(
      dialogTitle: '选择 KDBX 密码库',
      type: FileType.custom,
      allowedExtensions: const ['kdbx'],
    );
  } catch (error) {
    if (context.mounted) _showMessage(context, '无法选择文件：$error');
    return;
  }
  if (file == null || !context.mounted) return;

  final password = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _KdbxPasswordSheet.import(fileName: file!.name),
  );
  if (password == null || !context.mounted) return;

  Uint8List bytes;
  try {
    bytes = await file.readAsBytes();
  } catch (error) {
    if (context.mounted) _showMessage(context, '无法读取 KDBX 文件：$error');
    return;
  }
  final preview = await viewModel.prepareKdbxImport(
    bytes: bytes,
    password: password,
  );
  if (!context.mounted) return;
  if (preview == null) {
    _showMessage(context, viewModel.errorMessage ?? 'KDBX 导入失败');
    return;
  }
  if (preview.data.entries.isEmpty) {
    _showMessage(context, 'KDBX 中没有可导入的密码条目');
    return;
  }
  final selectedIndexes = await showModalBottomSheet<Set<int>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _KdbxImportReviewSheet(preview: preview),
  );
  if (selectedIndexes == null || !context.mounted) return;
  final summary = await viewModel.completeKdbxImport(preview, selectedIndexes);
  if (!context.mounted) return;
  if (summary == null) {
    _showMessage(context, viewModel.errorMessage ?? 'KDBX 导入失败');
    return;
  }
  _showMessage(
    context,
    summary.itemCount == 0
        ? '没有选择要导入的条目'
        : '已导入 ${summary.itemCount} 条密码，新增 ${summary.createdGroupCount} 个分组',
  );
}

class _KdbxImportReviewSheet extends StatefulWidget {
  const _KdbxImportReviewSheet({required this.preview});

  final KdbxImportPreview preview;

  @override
  State<_KdbxImportReviewSheet> createState() => _KdbxImportReviewSheetState();
}

class _KdbxImportReviewSheetState extends State<_KdbxImportReviewSheet> {
  late Set<int> _selectedIndexes;

  List<KdbxImportEntry> get _entries => widget.preview.data.entries;

  @override
  void initState() {
    super.initState();
    _selectedIndexes = {
      for (var index = 0; index < _entries.length; index++)
        if (!widget.preview.duplicateIndexes.contains(index)) index,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final problemCount = [
      for (var index = 0; index < _entries.length; index++)
        if (_issuesFor(index).isNotEmpty) index,
    ].length;
    return FractionallySizedBox(
      heightFactor: 0.9,
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '选择导入条目',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '共 ${_entries.length} 条 · 重复 ${widget.preview.duplicateCount} 条 · 有问题 $problemCount 条',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: _toggleAll,
                      icon: Icon(
                        _selectedIndexes.length == _entries.length
                            ? Icons.deselect_outlined
                            : Icons.select_all_outlined,
                      ),
                      label: Text(
                        _selectedIndexes.length == _entries.length
                            ? '取消全选'
                            : '全选',
                      ),
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      onPressed: _selectNormal,
                      icon: const Icon(Icons.verified_outlined),
                      label: const Text('只选正常项'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  itemCount: _entries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final entry = _entries[index];
                    final issues = _issuesFor(index);
                    final selected = _selectedIndexes.contains(index);
                    return Card(
                      elevation: 0,
                      margin: EdgeInsets.zero,
                      color: issues.isEmpty
                          ? theme.colorScheme.surfaceContainerLow
                          : theme.colorScheme.surfaceContainer,
                      child: CheckboxListTile(
                        value: selected,
                        onChanged: (_) => _toggle(index),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: const EdgeInsets.fromLTRB(8, 4, 14, 4),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                entry.title.trim().isEmpty
                                    ? '（无名称）'
                                    : entry.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            ...issues.map(
                              (issue) => Padding(
                                padding: const EdgeInsets.only(left: 5),
                                child: _ImportIssueBadge(issue: issue),
                              ),
                            ),
                            if (entry.totp != null)
                              Padding(
                                padding: const EdgeInsets.only(left: 5),
                                child: _ImportStatusBadge(
                                  label: '动态码',
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            [
                              entry.groupName,
                              if (entry.username.trim().isNotEmpty)
                                entry.username,
                              if (entry.url.trim().isNotEmpty) entry.url,
                              if (entry.totpError != null) entry.totpError!,
                            ].join(' · '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(
                    top: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('取消'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: _selectedIndexes.isEmpty
                            ? null
                            : () => Navigator.pop(
                                context,
                                Set<int>.from(_selectedIndexes),
                              ),
                        child: Text('导入（${_selectedIndexes.length}）'),
                      ),
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

  List<_ImportIssue> _issuesFor(int index) {
    final entry = _entries[index];
    return [
      if (widget.preview.duplicateIndexes.contains(index))
        _ImportIssue.duplicate,
      if (entry.title.trim().isEmpty) _ImportIssue.missingTitle,
      if (entry.password.isEmpty) _ImportIssue.missingPassword,
      if (entry.totpError != null) _ImportIssue.invalidTotp,
    ];
  }

  void _toggle(int index) {
    setState(() {
      if (!_selectedIndexes.remove(index)) _selectedIndexes.add(index);
    });
  }

  void _toggleAll() {
    setState(() {
      _selectedIndexes = _selectedIndexes.length == _entries.length
          ? <int>{}
          : {for (var index = 0; index < _entries.length; index++) index};
    });
  }

  void _selectNormal() {
    setState(() {
      _selectedIndexes = {
        for (var index = 0; index < _entries.length; index++)
          if (_issuesFor(index).isEmpty) index,
      };
    });
  }
}

enum _ImportIssue { duplicate, missingTitle, missingPassword, invalidTotp }

class _ImportIssueBadge extends StatelessWidget {
  const _ImportIssueBadge({required this.issue});

  final _ImportIssue issue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color) = switch (issue) {
      _ImportIssue.duplicate => ('重复', Colors.orange.shade800),
      _ImportIssue.missingTitle => ('缺名称', theme.colorScheme.error),
      _ImportIssue.missingPassword => ('缺密码', theme.colorScheme.error),
      _ImportIssue.invalidTotp => ('验证码异常', theme.colorScheme.error),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ImportStatusBadge extends StatelessWidget {
  const _ImportStatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

Future<void> _exportKdbx(BuildContext context, VaultViewModel viewModel) async {
  final password = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _KdbxPasswordSheet.export(),
  );
  if (password == null || !context.mounted) return;

  final bytes = await viewModel.exportKdbx(password);
  if (bytes == null || !context.mounted) {
    if (context.mounted) {
      _showMessage(context, viewModel.errorMessage ?? 'KDBX 导出失败');
    }
    return;
  }

  final now = DateTime.now();
  final fileName =
      '松匣-${now.year}${_twoDigits(now.month)}${_twoDigits(now.day)}-'
      '${_twoDigits(now.hour)}${_twoDigits(now.minute)}.kdbx';
  try {
    final saved = await FilePicker.saveFile(
      dialogTitle: '导出 KDBX 密码库',
      fileName: fileName,
      bytes: bytes,
      mimeType: 'application/x-keepass2',
    );
    if (saved != null && context.mounted) {
      _showMessage(context, 'KDBX 已导出');
    }
  } catch (error) {
    if (context.mounted) _showMessage(context, '无法保存 KDBX 文件：$error');
  }
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

void _showMessage(BuildContext context, String message) {
  showAppMessage(context, message);
}

enum _KdbxPasswordMode { import, export }

class _KdbxPasswordSheet extends StatefulWidget {
  const _KdbxPasswordSheet.import({required this.fileName})
    : mode = _KdbxPasswordMode.import;

  const _KdbxPasswordSheet.export()
    : mode = _KdbxPasswordMode.export,
      fileName = null;

  final _KdbxPasswordMode mode;
  final String? fileName;

  @override
  State<_KdbxPasswordSheet> createState() => _KdbxPasswordSheetState();
}

class _KdbxPasswordSheetState extends State<_KdbxPasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _obscurePassword = true;

  bool get _isExport => widget.mode == _KdbxPasswordMode.export;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
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
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _isExport ? '导出 KDBX' : '导入 KDBX',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isExport
                        ? '设置此 KDBX 文件自己的主密码，与松匣主密码互不影响。'
                        : '${widget.fileName}\n此密码只用于本次解密，不会保存到松匣。',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _password,
                    autofocus: true,
                    obscureText: _obscurePassword,
                    textInputAction: _isExport
                        ? TextInputAction.next
                        : TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: _isExport ? '设置 KDBX 主密码' : 'KDBX 主密码',
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
                      if ((value ?? '').isEmpty) return '请输入 KDBX 主密码';
                      if (_isExport && value!.length < 8) {
                        return 'KDBX 主密码至少需要 8 个字符';
                      }
                      return null;
                    },
                    onFieldSubmitted: _isExport ? null : (_) => _submit(),
                  ),
                  if (_isExport) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirmation,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: '确认 KDBX 主密码',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      validator: (value) =>
                          value != _password.text ? '两次输入的密码不一致' : null,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                  ],
                  const SizedBox(height: 20),
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
                          child: Text(_isExport ? '生成文件' : '开始导入'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(context, _password.text);
  }
}

Future<void> _sync(BuildContext context, VaultViewModel viewModel) async {
  final succeeded = await viewModel.sync();
  if (!context.mounted) return;
  final message = succeeded ? viewModel.syncMessage : viewModel.errorMessage;
  showAppMessage(context, message ?? '同步失败，请重试');
}
