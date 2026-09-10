import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../domain/models/backup_entry.dart';

class LocalBackupService {
  LocalBackupService({Future<Directory> Function()? directoryProvider})
    : _directoryProvider = directoryProvider ?? getApplicationSupportDirectory;

  static const automaticRetention = 10;
  final Future<Directory> Function() _directoryProvider;

  Future<BackupEntry> create(
    String vaultId,
    String contents, {
    required String prefix,
  }) async {
    final directory = await _directory(vaultId);
    await directory.create(recursive: true);
    final name = '$prefix-${_timestamp(DateTime.now().toUtc())}.pvlt';
    final target = File('${directory.path}/$name');
    final temporary = File('${target.path}.tmp');
    await temporary.writeAsString(contents, flush: true);
    await temporary.rename(target.path);
    if (prefix == 'auto') await _trimAutomatic(directory);
    return _entry(target, BackupLocation.local);
  }

  Future<List<BackupEntry>> list(String vaultId) async {
    final directory = await _directory(vaultId);
    if (!await directory.exists()) return const [];
    final entries = <BackupEntry>[];
    await for (final entity in directory.list()) {
      if (entity is File && entity.path.endsWith('.pvlt')) {
        entries.add(await _entry(entity, BackupLocation.local));
      }
    }
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries;
  }

  Future<String> read(String vaultId, String name) async {
    _validateName(name);
    return File('${(await _directory(vaultId)).path}/$name').readAsString();
  }

  Future<void> delete(String vaultId, String name) async {
    _validateName(name);
    final file = File('${(await _directory(vaultId)).path}/$name');
    if (await file.exists()) await file.delete();
  }

  Future<void> _trimAutomatic(Directory directory) async {
    final automatic = <File>[];
    await for (final entity in directory.list()) {
      if (entity is File &&
          entity.uri.pathSegments.last.startsWith('auto-') &&
          entity.path.endsWith('.pvlt')) {
        automatic.add(entity);
      }
    }
    automatic.sort((a, b) => b.path.compareTo(a.path));
    for (final file in automatic.skip(automaticRetention)) {
      await file.delete();
    }
  }

  Future<Directory> _directory(String vaultId) async {
    final support = await _directoryProvider();
    return Directory('${support.path}/PineVault/backups/$vaultId');
  }

  Future<BackupEntry> _entry(File file, BackupLocation location) async {
    final stat = await file.stat();
    return BackupEntry(
      name: file.uri.pathSegments.last,
      createdAt: stat.modified.toUtc(),
      size: stat.size,
      location: location,
    );
  }

  void _validateName(String name) {
    if (name.isEmpty || name.contains('/') || name.contains('\\')) {
      throw const FormatException('无效的备份文件名');
    }
  }

  String _timestamp(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}'
      '${value.month.toString().padLeft(2, '0')}'
      '${value.day.toString().padLeft(2, '0')}-'
      '${value.hour.toString().padLeft(2, '0')}'
      '${value.minute.toString().padLeft(2, '0')}'
      '${value.second.toString().padLeft(2, '0')}-'
      '${value.millisecond.toString().padLeft(3, '0')}';
}
