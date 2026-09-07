import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../vault/vault_view_model.dart';

class SyncHistoryScreen extends StatefulWidget {
  const SyncHistoryScreen({super.key});

  @override
  State<SyncHistoryScreen> createState() => _SyncHistoryScreenState();
}

class _SyncHistoryScreenState extends State<SyncHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VaultViewModel>().loadSyncHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final history = context.watch<VaultViewModel>().syncHistory;
    return Scaffold(
      appBar: AppBar(title: const Text('同步历史')),
      body: history.isEmpty
          ? const Center(child: Text('还没有同步记录'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: history.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (context, index) {
                final entry = history[index];
                final local = entry.timestamp.toLocal();
                final time =
                    '${local.year}-${_two(local.month)}-${_two(local.day)} '
                    '${_two(local.hour)}:${_two(local.minute)}:${_two(local.second)}';
                return ListTile(
                  leading: Icon(
                    entry.success
                        ? Icons.check_circle_outline
                        : Icons.error_outline,
                    color: entry.success
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.error,
                  ),
                  title: Text(entry.message),
                  subtitle: Text('${entry.trigger} · $time'),
                );
              },
            ),
    );
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}
