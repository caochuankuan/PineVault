import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pine_vault/data/models/vault_envelope.dart';
import 'package:pine_vault/data/repositories/vault_repository.dart';
import 'package:pine_vault/data/serialization/vault_codec.dart';
import 'package:pine_vault/data/services/crypto_service.dart';
import 'package:pine_vault/data/services/vault_file_service.dart';
import 'package:pine_vault/domain/models/vault.dart';
import 'package:pine_vault/domain/models/vault_item.dart';
import 'package:pine_vault/domain/models/webdav_configuration.dart';
import 'package:sodium_libs/sodium_libs_sumo.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late SodiumCryptoService cryptoService;
  const codec = VaultCodec();

  setUpAll(() async {
    cryptoService = SodiumCryptoService(await SodiumSumoInit.init());
  });

  testWidgets('encrypts and unlocks with the correct master password', (
    tester,
  ) async {
    final created = cryptoService.createVault(
      masterPassword: 'correct horse battery staple',
      vault: _sampleVault(),
    );
    addTearDown(created.key.dispose);

    final unlocked = cryptoService.unlock(
      masterPassword: 'correct horse battery staple',
      envelope: created.envelope,
    );
    addTearDown(unlocked.key.dispose);

    expect(unlocked.vault.items.single.password, 'highly-secret-password');
    final fileContents = codec.encodeEnvelope(created.envelope);
    expect(fileContents, isNot(contains('Example account')));
    expect(fileContents, isNot(contains('highly-secret-password')));
  });

  testWidgets('rejects an incorrect master password', (tester) async {
    final created = cryptoService.createVault(
      masterPassword: 'correct horse battery staple',
      vault: _sampleVault(),
    );
    addTearDown(created.key.dispose);

    expect(
      () => cryptoService.unlock(
        masterPassword: 'this password is definitely wrong',
        envelope: created.envelope,
      ),
      throwsA(isA<VaultUnlockException>()),
    );
  });

  testWidgets('rejects a modified encrypted payload', (tester) async {
    final created = cryptoService.createVault(
      masterPassword: 'correct horse battery staple',
      vault: _sampleVault(),
    );
    addTearDown(created.key.dispose);
    final cipherText = base64Decode(created.envelope.payload.ciphertext);
    cipherText[cipherText.length ~/ 2] ^= 1;
    final modified = created.envelope.copyWithPayload(
      CipherPayload(
        nonce: created.envelope.payload.nonce,
        ciphertext: base64Encode(cipherText),
      ),
    );

    expect(
      () => cryptoService.unlock(
        masterPassword: 'correct horse battery staple',
        envelope: modified,
      ),
      throwsA(isA<VaultUnlockException>()),
    );
  });

  testWidgets('persists an item and unlocks it after locking', (tester) async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'pine_vault_test_',
    );
    final repository = VaultRepository(
      cryptoService: cryptoService,
      fileService: VaultFileService(
        directoryProvider: () async => temporaryDirectory,
      ),
      codec: codec,
    );
    addTearDown(() async {
      repository.lock();
      await temporaryDirectory.delete(recursive: true);
    });

    const masterPassword = 'correct horse battery staple';
    await repository.create(masterPassword);
    await repository.upsert(
      title: 'Saved account',
      username: 'person@example.com',
      password: 'persisted-secret',
      url: 'https://example.com',
      notes: 'encrypted note',
      favorite: true,
    );

    final file = File('${temporaryDirectory.path}/PineVault/vault.pvlt');
    final contents = await file.readAsString();
    expect(contents, isNot(contains('Saved account')));
    expect(contents, isNot(contains('persisted-secret')));

    repository.lock();
    expect(repository.vault, isNull);
    await repository.unlock(masterPassword);

    final item = repository.vault!.items.single;
    expect(item.title, 'Saved account');
    expect(item.password, 'persisted-secret');
    expect(item.favorite, isTrue);
  });

  testWidgets('changes the master password without changing vault data', (
    tester,
  ) async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'pine_vault_password_change_',
    );
    final repository = VaultRepository(
      cryptoService: cryptoService,
      fileService: VaultFileService(
        directoryProvider: () async => temporaryDirectory,
      ),
      codec: codec,
    );
    addTearDown(() async {
      repository.lock();
      await temporaryDirectory.delete(recursive: true);
    });

    const oldPassword = 'correct horse battery staple';
    const newPassword = '87654321';
    await repository.create(oldPassword);
    await repository.upsert(
      title: 'Preserved account',
      username: 'person@example.com',
      password: 'preserved-secret',
      url: '',
      notes: '',
      favorite: false,
    );
    await repository.changeMasterPassword(
      currentPassword: oldPassword,
      newPassword: newPassword,
    );
    repository.lock();

    await expectLater(
      repository.unlock(oldPassword),
      throwsA(isA<VaultUnlockException>()),
    );
    await repository.unlock(newPassword);
    expect(repository.vault!.items.single.password, 'preserved-secret');
  });

  testWidgets('device key unlock survives a master password change', (
    tester,
  ) async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'pine_vault_device_unlock_',
    );
    final repository = VaultRepository(
      cryptoService: cryptoService,
      fileService: VaultFileService(
        directoryProvider: () async => temporaryDirectory,
      ),
      codec: codec,
    );
    addTearDown(() async {
      repository.lock();
      await temporaryDirectory.delete(recursive: true);
    });

    const oldPassword = 'correct horse battery staple';
    await repository.create(oldPassword);
    await repository.upsert(
      title: 'Device unlocked account',
      username: 'person@example.com',
      password: 'device-protected-secret',
      url: '',
      notes: '',
      favorite: false,
    );
    final rawDeviceKey = repository.exportDeviceUnlockKey(oldPassword);
    addTearDown(() => rawDeviceKey.fillRange(0, rawDeviceKey.length, 0));

    await repository.changeMasterPassword(
      currentPassword: oldPassword,
      newPassword: 'new-password-123',
    );
    repository.lock();
    await repository.unlockWithDeviceKey(rawDeviceKey);

    expect(repository.vault!.items.single.password, 'device-protected-secret');
  });

  testWidgets('restores an encrypted snapshot over the current vault', (
    tester,
  ) async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'pine_vault_restore_existing_',
    );
    final repository = VaultRepository(
      cryptoService: cryptoService,
      fileService: VaultFileService(
        directoryProvider: () async => temporaryDirectory,
      ),
      codec: codec,
    );
    addTearDown(() async {
      repository.lock();
      await temporaryDirectory.delete(recursive: true);
    });

    const password = 'correct horse battery staple';
    await repository.create(password);
    await repository.upsert(
      title: 'Backup version',
      username: 'old@example.com',
      password: 'old-secret',
      url: '',
      notes: '',
      favorite: false,
    );
    final backup = repository.exportEncryptedVault();
    await repository.saveWebDavCredentials(
      WebDavCredentials(
        serverUri: Uri.parse('https://dav.example.test/'),
        username: 'current@example.com',
        password: 'application-password',
      ),
    );
    final item = repository.vault!.items.single;
    await repository.upsert(
      existing: item,
      title: 'Current version',
      username: item.username,
      password: 'current-secret',
      url: '',
      notes: '',
      favorite: false,
    );

    final prepared = repository.prepareRestoreExisting(password, backup);
    await repository.restoreExisting(password, prepared);

    expect(repository.vault!.items.single.title, 'Backup version');
    expect(repository.vault!.items.single.password, 'old-secret');
    expect(
      repository.vault!.webDavCredentials?.username,
      'current@example.com',
    );
    repository.lock();
    await repository.unlock(password);
    expect(repository.vault!.items.single.title, 'Backup version');
  });
}

Vault _sampleVault() {
  final now = DateTime.utc(2026, 9, 7, 3);
  return Vault(
    id: 'vault-id',
    schemaVersion: 1,
    createdAt: now,
    updatedAt: now,
    items: [
      VaultItem(
        id: 'item-id',
        type: VaultItemType.login,
        title: 'Example account',
        username: 'person@example.com',
        password: 'highly-secret-password',
        urls: const ['https://example.com'],
        notes: '',
        favorite: false,
        createdAt: now,
        updatedAt: now,
        revision: 1,
      ),
    ],
    tombstones: const [],
  );
}
