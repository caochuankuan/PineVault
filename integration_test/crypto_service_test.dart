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
