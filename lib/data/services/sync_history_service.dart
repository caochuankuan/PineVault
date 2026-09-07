import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/sync_history_entry.dart';
import 'vault_file_service.dart';

class SyncHistoryService {
  SyncHistoryService({DirectoryProvider? directoryProvider})
    : _directoryProvider = directoryProvider ?? getApplicationSupportDirectory;

  static const _maximumEntries = 100;
  final DirectoryProvider _directoryProvider;

  Future<List<SyncHistoryEntry>> read(String vaultId) async {
    final file = await _file(vaultId);
    if (!await file.exists()) return const [];
    final value = jsonDecode(await file.readAsString());
    if (value is! List<dynamic>) {
      throw const FormatException('Invalid sync history.');
    }
    return List.unmodifiable(
      value.map(
        (entry) => SyncHistoryEntry.fromJson(entry as Map<String, dynamic>),
      ),
    );
  }

  Future<List<SyncHistoryEntry>> append(
    String vaultId,
    SyncHistoryEntry entry,
  ) async {
    final entries = [entry, ...await read(vaultId)];
    if (entries.length > _maximumEntries) {
      entries.removeRange(_maximumEntries, entries.length);
    }
    final file = await _file(vaultId);
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      jsonEncode(entries.map((item) => item.toJson()).toList()),
      flush: true,
    );
    if (await file.exists()) await file.delete();
    await temporary.rename(file.path);
    return List.unmodifiable(entries);
  }

  Future<File> _file(String vaultId) async {
    final support = await _directoryProvider();
    return File('${support.path}/PineVault/sync-history-$vaultId.json');
  }
}
