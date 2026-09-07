import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/sync_state.dart';
import 'vault_file_service.dart';

class SyncStateService {
  SyncStateService({DirectoryProvider? directoryProvider})
    : _directoryProvider = directoryProvider ?? getApplicationSupportDirectory;

  final DirectoryProvider _directoryProvider;

  Future<SyncState?> read(String vaultId) async {
    final file = await _file(vaultId);
    if (!await file.exists()) return null;
    final value = jsonDecode(await file.readAsString());
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid sync state.');
    }
    return SyncState.fromJson(value);
  }

  Future<void> write(String vaultId, SyncState state) async {
    final file = await _file(vaultId);
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode(state.toJson()), flush: true);
    if (await file.exists()) await file.delete();
    await temporary.rename(file.path);
  }

  Future<File> _file(String vaultId) async {
    final support = await _directoryProvider();
    return File('${support.path}/PineVault/sync-$vaultId.json');
  }
}
