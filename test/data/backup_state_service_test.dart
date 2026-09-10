import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pine_vault/data/services/backup_state_service.dart';

void main() {
  late Directory directory;
  late BackupStateService service;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('pine-vault-state-');
    service = BackupStateService(directoryProvider: () async => directory);
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('persists automatic backup settings and timestamps', () async {
    final localAt = DateTime.utc(2026, 9, 7, 1, 2, 3);
    final webDavAt = DateTime.utc(2026, 9, 8, 4, 5, 6);

    await service.write('vault-id', const BackupState());
    await service.write(
      'vault-id',
      BackupState(
        automaticEnabled: false,
        lastLocalAt: localAt,
        lastWebDavAt: webDavAt,
      ),
    );
    final restored = await service.read('vault-id');

    expect(restored.automaticEnabled, isFalse);
    expect(restored.lastLocalAt, localAt);
    expect(restored.lastWebDavAt, webDavAt);
  });

  test('uses safe defaults when the state file is corrupt', () async {
    final file = File('${directory.path}/PineVault/backup-state-vault-id.json');
    await file.parent.create(recursive: true);
    await file.writeAsString('{not-json');

    final restored = await service.read('vault-id');

    expect(restored.automaticEnabled, isTrue);
    expect(restored.lastLocalAt, isNull);
    expect(restored.lastWebDavAt, isNull);
  });
}
