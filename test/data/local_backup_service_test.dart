import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pine_vault/data/services/local_backup_service.dart';

void main() {
  test('keeps only the ten newest automatic backups', () async {
    final root = await Directory.systemTemp.createTemp('pinevault-backup-test');
    addTearDown(() => root.delete(recursive: true));
    final service = LocalBackupService(directoryProvider: () async => root);

    for (var index = 0; index < 11; index++) {
      await service.create('vault-id', 'encrypted-$index', prefix: 'auto');
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }

    final backups = await service.list('vault-id');
    expect(backups.where((entry) => entry.isAutomatic), hasLength(10));
  });

  test(
    'does not remove restore points while trimming automatic backups',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'pinevault-backup-test',
      );
      addTearDown(() => root.delete(recursive: true));
      final service = LocalBackupService(directoryProvider: () async => root);

      await service.create('vault-id', 'before', prefix: 'restore-before');
      for (var index = 0; index < 11; index++) {
        await service.create('vault-id', 'encrypted-$index', prefix: 'auto');
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }

      final backups = await service.list('vault-id');
      expect(backups.where((entry) => entry.isRestorePoint), hasLength(1));
      expect(backups.where((entry) => entry.isAutomatic), hasLength(10));
    },
  );
}
