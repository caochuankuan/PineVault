import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pine_vault/data/models/sync_state.dart';
import 'package:pine_vault/data/repositories/backup_repository.dart';
import 'package:pine_vault/data/repositories/vault_repository.dart';
import 'package:pine_vault/data/repositories/webdav_repository.dart';
import 'package:pine_vault/data/services/backup_state_service.dart';
import 'package:pine_vault/data/services/local_backup_service.dart';
import 'package:pine_vault/data/services/sync_state_service.dart';
import 'package:pine_vault/data/services/webdav_service.dart';
import 'package:pine_vault/domain/models/backup_entry.dart';
import 'package:pine_vault/domain/models/webdav_configuration.dart';

void main() {
  late List<String> events;
  late _FakeVaultRepository vaultRepository;
  late _FakeWebDavRepository webDavRepository;
  late _FakeLocalBackupService localService;
  late _FakeBackupStateService stateService;
  late _FakeSyncStateService syncStateService;
  late BackupRepository repository;

  setUp(() {
    events = [];
    vaultRepository = _FakeVaultRepository(events);
    webDavRepository = _FakeWebDavRepository(events);
    localService = _FakeLocalBackupService(events);
    stateService = _FakeBackupStateService();
    syncStateService = _FakeSyncStateService();
    repository = BackupRepository(
      vaultRepository: vaultRepository,
      webDavRepository: webDavRepository,
      localService: localService,
      stateService: stateService,
      syncStateService: syncStateService,
    );
  });

  test('validates a restore before creating restore points', () async {
    await expectLater(
      repository.restore('backup', 'wrong-password'),
      throwsFormatException,
    );

    expect(events, ['prepare']);
    expect(vaultRepository.currentEnvelope, 'current');
  });

  test('does not change local data when WebDAV replacement fails', () async {
    webDavRepository.failVaultUpload = true;

    await expectLater(
      repository.restore('backup', 'correct-password'),
      throwsA(isA<WebDavException>()),
    );

    expect(vaultRepository.currentEnvelope, 'current');
    expect(
      events,
      containsAllInOrder(['local-backup', 'remote-backup', 'vault-upload']),
    );
    expect(events, isNot(contains('local-restore')));
  });

  test('replaces WebDAV before committing the local restore', () async {
    final result = await repository.restore('backup', 'correct-password');

    expect(result.webDavSynced, isTrue);
    expect(result.webDavConfigured, isTrue);
    expect(utf8.decode(webDavRepository.uploadedVault!), 'prepared');
    expect(
      events.indexOf('vault-upload'),
      lessThan(events.indexOf('local-restore')),
    );
    expect(vaultRepository.currentEnvelope, 'prepared');
    expect(syncStateService.written?.baseEnvelope, 'prepared');
    expect(syncStateService.written?.etag, '"new"');
  });

  test('restores locally when WebDAV is not configured', () async {
    webDavRepository.configured = false;

    final result = await repository.restore('backup', 'correct-password');

    expect(result.webDavSynced, isFalse);
    expect(result.webDavConfigured, isFalse);
    expect(vaultRepository.currentEnvelope, 'prepared');
    expect(events, isNot(contains('vault-upload')));
  });

  test(
    'accepts another device creating the same daily automatic backup',
    () async {
      webDavRepository.conflictOnBackupUpload = true;

      await repository.createWebDav(prefix: 'auto');

      expect(stateService.state.lastWebDavAt, isNotNull);
    },
  );
}

class _FakeVaultRepository implements VaultRepository {
  _FakeVaultRepository(this.events);

  final List<String> events;
  String currentEnvelope = 'current';

  @override
  String? get currentVaultId => 'vault-id';

  @override
  String exportEncryptedVault() => currentEnvelope;

  @override
  String prepareRestoreExisting(String masterPassword, String encoded) {
    events.add('prepare');
    if (masterPassword != 'correct-password') {
      throw const FormatException('wrong password');
    }
    return 'prepared';
  }

  @override
  Future<void> restoreExisting(String masterPassword, String encoded) async {
    events.add('local-restore');
    currentEnvelope = encoded;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeWebDavRepository implements WebDavRepository {
  _FakeWebDavRepository(this.events);

  final List<String> events;
  bool configured = true;
  bool failVaultUpload = false;
  bool conflictOnBackupUpload = false;
  List<int>? uploadedVault;

  @override
  Future<WebDavConfiguration?> loadConfiguration() async => configured
      ? const WebDavConfiguration(
          serverUrl: 'https://dav.example.test/',
          username: 'person@example.com',
          hasPassword: true,
        )
      : null;

  @override
  Future<void> ensureBackupDirectory(String vaultId) async {}

  @override
  Future<void> uploadBackup(
    String vaultId,
    String name,
    List<int> bytes,
  ) async {
    events.add('remote-backup');
    if (conflictOnBackupUpload) {
      throw const WebDavException('exists', statusCode: 412);
    }
  }

  @override
  Future<List<WebDavBackupFile>> listBackups(String vaultId) async => [
    WebDavBackupFile(
      name: 'auto-20260910.pvlt',
      size: 8,
      createdAt: DateTime.now().toUtc(),
    ),
  ];

  @override
  Future<WebDavRemoteFile?> downloadVault() async =>
      WebDavRemoteFile(bytes: Uint8List.fromList([1]), etag: '"old"');

  @override
  Future<String?> uploadVault(
    List<int> bytes, {
    String? expectedEtag,
    bool createOnly = false,
  }) async {
    events.add('vault-upload');
    if (failVaultUpload) {
      throw const WebDavException('offline');
    }
    uploadedVault = bytes;
    return '"new"';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeLocalBackupService implements LocalBackupService {
  _FakeLocalBackupService(this.events);

  final List<String> events;

  @override
  Future<BackupEntry> create(
    String vaultId,
    String contents, {
    required String prefix,
  }) async {
    events.add('local-backup');
    return BackupEntry(
      name: '$prefix.pvlt',
      createdAt: DateTime.now().toUtc(),
      size: contents.length,
      location: BackupLocation.local,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeBackupStateService implements BackupStateService {
  BackupState state = const BackupState();

  @override
  Future<BackupState> read(String vaultId) async => state;

  @override
  Future<void> write(String vaultId, BackupState value) async {
    state = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSyncStateService implements SyncStateService {
  SyncState? written;

  @override
  Future<void> write(String vaultId, SyncState state) async {
    written = state;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
