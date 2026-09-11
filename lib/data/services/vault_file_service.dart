import 'dart:io';

import 'package:path_provider/path_provider.dart';

typedef DirectoryProvider = Future<Directory> Function();

class VaultFileService {
  VaultFileService({DirectoryProvider? directoryProvider})
    : _directoryProvider = directoryProvider ?? getApplicationSupportDirectory;

  final DirectoryProvider _directoryProvider;

  Future<bool> exists() async {
    final files = await _files();
    return await files.current.exists() || await files.backup.exists();
  }

  Future<String> read() async {
    final files = await _files();
    if (await files.current.exists()) {
      return files.current.readAsString();
    }
    if (await files.backup.exists()) {
      return files.backup.readAsString();
    }
    throw const FileSystemException('松匣密码库文件不存在。');
  }

  Future<void> write(String contents) async {
    final files = await _files();
    await files.directory.create(recursive: true);
    await files.temporary.writeAsString(contents, flush: true);

    if (await files.backup.exists()) {
      await files.backup.delete();
    }
    if (await files.current.exists()) {
      await files.current.rename(files.backup.path);
    }
    await files.temporary.rename(files.current.path);
  }

  Future<_VaultFiles> _files() async {
    final supportDirectory = await _directoryProvider();
    final directory = Directory('${supportDirectory.path}/PineVault');
    return _VaultFiles(
      directory: directory,
      current: File('${directory.path}/vault.pvlt'),
      backup: File('${directory.path}/vault.prev.pvlt'),
      temporary: File('${directory.path}/vault.tmp'),
    );
  }
}

class _VaultFiles {
  const _VaultFiles({
    required this.directory,
    required this.current,
    required this.backup,
    required this.temporary,
  });

  final Directory directory;
  final File current;
  final File backup;
  final File temporary;
}
