import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/models/backup_entry.dart';
import '../../core/app_feedback.dart';
import 'backup_view_model.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BackupViewModel>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<BackupViewModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('备份与恢复')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('超过 3 天未备份时自动备份'),
            subtitle: const Text('进入首页后检查，本地和 WebDAV 分别记录'),
            value: viewModel.state.automaticEnabled,
            onChanged: viewModel.actionsDisabled
                ? null
                : (value) => _setAutomatic(viewModel, value),
          ),
          const SizedBox(height: 8),
          _StatusRow(label: '最近本地备份', value: viewModel.state.lastLocalAt),
          _StatusRow(
            label: '最近 WebDAV 备份',
            value: viewModel.state.lastWebDavAt,
          ),
          const SizedBox(height: 20),
          Text('立即备份', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: viewModel.actionsDisabled
                    ? null
                    : () => _exportLocal(viewModel),
                icon: const Icon(Icons.save_alt_outlined),
                label: const Text('备份到本地'),
              ),
              OutlinedButton.icon(
                onPressed: viewModel.actionsDisabled
                    ? null
                    : () => _run(viewModel.createWebDav),
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('备份到 WebDAV'),
              ),
            ],
          ),
          const SizedBox(height: 28),
          _BackupSection(
            title: '本地自动备份',
            entries: viewModel.local,
            busy: viewModel.actionsDisabled,
            onRestore: (entry) => _restore(viewModel, entry),
            onDelete: (entry) => _delete(viewModel, entry),
          ),
          OutlinedButton.icon(
            onPressed: viewModel.actionsDisabled
                ? null
                : () => _restoreFromFile(viewModel),
            icon: const Icon(Icons.file_open_outlined),
            label: const Text('从本地备份文件恢复'),
          ),
          const SizedBox(height: 22),
          _BackupSection(
            title: 'WebDAV 备份',
            entries: viewModel.webDav,
            busy: viewModel.actionsDisabled,
            onRestore: (entry) => _restore(viewModel, entry),
            onDelete: (entry) => _delete(viewModel, entry),
          ),
          if (viewModel.busy) ...[
            const SizedBox(height: 20),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }

  Future<void> _exportLocal(BackupViewModel viewModel) async {
    final now = DateTime.now();
    final name = '松匣-${_stamp(now)}.pvlt';
    try {
      final snapshot = await viewModel.prepareExport();
      if (snapshot == null) {
        if (mounted && viewModel.message != null) {
          showAppMessage(context, viewModel.message!);
        }
        return;
      }
      final path = await FilePicker.saveFile(
        dialogTitle: '备份松匣密码库',
        fileName: name,
        bytes: utf8.encode(snapshot.encoded),
        mimeType: 'application/octet-stream',
      );
      if (path == null) return;
      await viewModel.recordManualLocalBackup(snapshot.vaultId);
      if (mounted) showAppMessage(context, '本地备份成功');
    } catch (error) {
      if (mounted) showAppMessage(context, '本地备份失败：$error');
    }
  }

  Future<void> _run(Future<bool> Function() operation) async {
    await operation();
    if (!mounted) return;
    final message = context.read<BackupViewModel>().message;
    if (message != null) showAppMessage(context, message);
  }

  Future<void> _setAutomatic(BackupViewModel viewModel, bool value) async {
    final saved = await viewModel.setAutomatic(value);
    if (!mounted) return;
    if (!saved) {
      final message = viewModel.message;
      if (message != null) showAppMessage(context, message);
      return;
    }
    if (value) await _run(viewModel.checkAutomatic);
  }

  Future<void> _delete(BackupViewModel viewModel, BackupEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除备份？'),
        content: Text(entry.name),
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
    if (confirmed == true) await _run(() => viewModel.delete(entry));
  }

  Future<void> _restore(BackupViewModel viewModel, BackupEntry entry) async {
    final encoded = await viewModel.read(entry);
    if (encoded == null || !mounted) return;
    await _restoreEncoded(
      viewModel,
      encoded,
      title: '恢复到 ${_date(entry.createdAt)}？',
    );
  }

  Future<void> _restoreFromFile(BackupViewModel viewModel) async {
    try {
      final file = await FilePicker.pickFile(
        dialogTitle: '选择松匣备份',
        type: FileType.custom,
        allowedExtensions: const ['pvlt'],
      );
      if (file == null || !mounted) return;
      final encoded = utf8.decode(await file.readAsBytes());
      if (!mounted) return;
      await _restoreEncoded(viewModel, encoded, title: '恢复 ${file.name}？');
    } catch (error) {
      if (mounted) showAppMessage(context, '无法读取备份：$error');
    }
  }

  Future<void> _restoreEncoded(
    BackupViewModel viewModel,
    String encoded, {
    required String title,
  }) async {
    final password = await _askPassword();
    if (password == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: const Text('当前密码库会先自动备份，恢复完成后会同步到 WebDAV。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('恢复'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _run(() => viewModel.restore(encoded, password));
    }
  }

  Future<String?> _askPassword() async {
    final controller = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('输入备份主密码'),
          content: TextField(
            controller: controller,
            autofocus: true,
            obscureText: true,
            onSubmitted: (value) => Navigator.pop(context, value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('继续'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value});
  final String label;
  final DateTime? value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(value == null ? '尚未备份' : _date(value!)),
      ],
    ),
  );
}

class _BackupSection extends StatelessWidget {
  const _BackupSection({
    required this.title,
    required this.entries,
    required this.busy,
    required this.onRestore,
    required this.onDelete,
  });
  final String title;
  final List<BackupEntry> entries;
  final bool busy;
  final ValueChanged<BackupEntry> onRestore;
  final ValueChanged<BackupEntry> onDelete;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      if (entries.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Text('暂无备份'),
        )
      else
        for (final entry in entries)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              entry.location == BackupLocation.local
                  ? Icons.folder_outlined
                  : Icons.cloud_outlined,
            ),
            title: Text(_date(entry.createdAt)),
            subtitle: Text(
              '${entry.isAutomatic
                  ? '自动备份'
                  : entry.isRestorePoint
                  ? '恢复前备份'
                  : '手动备份'} · ${_size(entry.size)}',
            ),
            trailing: PopupMenuButton<String>(
              enabled: !busy,
              onSelected: (value) =>
                  value == 'restore' ? onRestore(entry) : onDelete(entry),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'restore', child: Text('恢复')),
                PopupMenuItem(value: 'delete', child: Text('删除')),
              ],
            ),
          ),
    ],
  );
}

String _date(DateTime value) {
  final local = value.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String _stamp(DateTime value) =>
    '${value.year}${value.month.toString().padLeft(2, '0')}${value.day.toString().padLeft(2, '0')}-'
    '${value.hour.toString().padLeft(2, '0')}${value.minute.toString().padLeft(2, '0')}${value.second.toString().padLeft(2, '0')}';

String _size(int bytes) => bytes < 1024
    ? '$bytes B'
    : bytes < 1024 * 1024
    ? '${(bytes / 1024).toStringAsFixed(1)} KB'
    : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
