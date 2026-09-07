import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pine_vault/data/repositories/vault_repository.dart';
import 'package:pine_vault/data/repositories/webdav_repository.dart';
import 'package:pine_vault/data/serialization/vault_codec.dart';
import 'package:pine_vault/data/services/crypto_service.dart';
import 'package:pine_vault/data/services/sync_state_service.dart';
import 'package:pine_vault/data/services/vault_file_service.dart';
import 'package:pine_vault/data/services/webdav_credential_store.dart';
import 'package:pine_vault/data/services/webdav_service.dart';
import 'package:pine_vault/domain/models/webdav_configuration.dart';
import 'package:pine_vault/domain/use_cases/restore_vault_use_case.dart';
import 'package:pine_vault/domain/use_cases/sync_vault_use_case.dart';
import 'package:pine_vault/domain/use_cases/vault_merge_service.dart';
import 'package:sodium_libs/sodium_libs_sumo.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('uploads and conflict-merges an encrypted vault with ETag', (
    tester,
  ) async {
    final root = await Directory.systemTemp.createTemp('pine_sync_test_');
    final remoteRoot = await Directory.systemTemp.createTemp(
      'pine_sync_remote_',
    );
    final restoredRoot = await Directory.systemTemp.createTemp(
      'pine_sync_restored_',
    );
    final rejectedRoot = await Directory.systemTemp.createTemp(
      'pine_sync_rejected_',
    );
    addTearDown(() async {
      await root.delete(recursive: true);
      await remoteRoot.delete(recursive: true);
      await restoredRoot.delete(recursive: true);
      await rejectedRoot.delete(recursive: true);
    });
    final sodium = await SodiumSumoInit.init();
    const codec = VaultCodec();
    final crypto = SodiumCryptoService(sodium);
    final localRepository = VaultRepository(
      cryptoService: crypto,
      fileService: VaultFileService(directoryProvider: () async => root),
      codec: codec,
    );
    addTearDown(localRepository.lock);

    List<int>? remoteBytes;
    var etagVersion = 0;
    var rejectNextConditionalUpload = false;
    final client = MockClient((request) async {
      if (request.method == 'GET') {
        if (remoteBytes == null) return http.Response('', 404);
        return http.Response.bytes(
          remoteBytes!,
          200,
          headers: {'etag': '"$etagVersion"'},
        );
      }
      if (request.method == 'PROPFIND') return http.Response('', 207);
      if (request.method == 'MKCOL') return http.Response('', 405);
      if (request.method == 'PUT') {
        if (remoteBytes == null) {
          expect(request.headers['if-none-match'], '*');
        } else {
          expect(request.headers['if-match'], '"$etagVersion"');
          if (rejectNextConditionalUpload) {
            rejectNextConditionalUpload = false;
            return http.Response('', 412);
          }
        }
        remoteBytes = request.bodyBytes;
        etagVersion++;
        return http.Response('', 204, headers: {'etag': '"$etagVersion"'});
      }
      return http.Response('', 500);
    });
    final webDavRepository = WebDavRepository(
      credentialStore: _MemoryCredentialStore(),
      service: WebDavService(client: client),
    );
    final sync = SyncVaultUseCase(
      vaultRepository: localRepository,
      webDavRepository: webDavRepository,
      stateService: SyncStateService(directoryProvider: () async => root),
      mergeService: VaultMergeService(),
    );

    const masterPassword = 'correct horse battery staple';
    await localRepository.create(masterPassword);
    await localRepository.upsert(
      title: 'Account',
      username: 'local@example.com',
      password: 'initial-password',
      url: '',
      notes: '',
      favorite: false,
    );
    final first = await sync();
    expect(first.outcome, VaultSyncOutcome.uploaded);
    expect(utf8.decode(remoteBytes!), isNot(contains('initial-password')));

    final restoredRepository = VaultRepository(
      cryptoService: crypto,
      fileService: VaultFileService(
        directoryProvider: () async => restoredRoot,
      ),
      codec: codec,
    );
    addTearDown(restoredRepository.lock);
    final restore = RestoreVaultUseCase(
      vaultRepository: restoredRepository,
      webDavRepository: webDavRepository,
      stateService: SyncStateService(
        directoryProvider: () async => restoredRoot,
      ),
    );
    await restore(
      serverUrl: 'https://dav.example.test/dav/',
      username: 'integration@example.com',
      applicationPassword: 'application-password',
      masterPassword: masterPassword,
    );
    expect(restoredRepository.vault!.items.single.title, 'Account');
    expect(restoredRepository.vault!.items.single.password, 'initial-password');

    final emptyStore = _MemoryCredentialStore.empty();
    final rejectedRepository = VaultRepository(
      cryptoService: crypto,
      fileService: VaultFileService(
        directoryProvider: () async => rejectedRoot,
      ),
      codec: codec,
    );
    final rejectedRestore = RestoreVaultUseCase(
      vaultRepository: rejectedRepository,
      webDavRepository: WebDavRepository(
        credentialStore: emptyStore,
        service: WebDavService(client: client),
      ),
      stateService: SyncStateService(
        directoryProvider: () async => rejectedRoot,
      ),
    );
    await expectLater(
      rejectedRestore(
        serverUrl: 'https://dav.example.test/dav/',
        username: 'integration@example.com',
        applicationPassword: 'application-password',
        masterPassword: 'wrong master password',
      ),
      throwsA(isA<VaultUnlockException>()),
    );
    expect(await rejectedRepository.hasVault(), isFalse);
    expect(emptyStore.credentials, isNull);

    final remoteFileService = VaultFileService(
      directoryProvider: () async => remoteRoot,
    );
    await remoteFileService.write(utf8.decode(remoteBytes!));
    final remoteRepository = VaultRepository(
      cryptoService: crypto,
      fileService: remoteFileService,
      codec: codec,
    );
    addTearDown(remoteRepository.lock);
    await remoteRepository.unlock(masterPassword);
    final remoteItem = remoteRepository.vault!.items.single;
    await remoteRepository.upsert(
      existing: remoteItem,
      title: remoteItem.title,
      username: remoteItem.username,
      password: 'remote-password',
      url: '',
      notes: '',
      favorite: false,
    );
    remoteBytes = utf8.encode(remoteRepository.exportEncryptedVault());
    etagVersion++;

    final localItem = localRepository.vault!.items.single;
    await localRepository.upsert(
      existing: localItem,
      title: 'Locally renamed',
      username: localItem.username,
      password: localItem.password,
      url: '',
      notes: '',
      favorite: false,
    );
    rejectNextConditionalUpload = true;
    await expectLater(sync(), throwsA(isA<WebDavException>()));
    expect(localRepository.vault!.items, hasLength(1));

    final merged = await sync();

    expect(merged.outcome, VaultSyncOutcome.merged);
    expect(merged.conflictCount, 1);
    expect(localRepository.vault!.items, hasLength(2));
    expect(
      localRepository.vault!.items.any((item) => item.title.endsWith('（同步冲突）')),
      isTrue,
    );
    expect(utf8.decode(remoteBytes!), isNot(contains('remote-password')));
  });
}

class _MemoryCredentialStore implements WebDavCredentialStore {
  _MemoryCredentialStore()
    : credentials = WebDavCredentials(
        serverUri: Uri.parse('https://dav.example.test/dav/'),
        username: 'integration@example.com',
        password: 'application-password',
      );

  _MemoryCredentialStore.empty();

  WebDavCredentials? credentials;

  @override
  Future<void> clear() async => credentials = null;

  @override
  Future<WebDavCredentials?> read() async => credentials;

  @override
  Future<void> write(WebDavCredentials value) async => credentials = value;
}
