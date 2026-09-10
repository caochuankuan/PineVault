import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pine_vault/data/repositories/vault_repository.dart';
import 'package:pine_vault/data/serialization/vault_codec.dart';
import 'package:pine_vault/data/services/crypto_service.dart';
import 'package:pine_vault/data/services/device_unlock_service.dart';
import 'package:pine_vault/data/services/kdbx_transfer_service.dart';
import 'package:pine_vault/data/services/sync_history_service.dart';
import 'package:pine_vault/data/services/vault_file_service.dart';
import 'package:pine_vault/domain/use_cases/restore_vault_use_case.dart';
import 'package:pine_vault/domain/use_cases/sync_vault_use_case.dart';
import 'package:pine_vault/ui/features/vault/vault_view_model.dart';
import 'package:sodium_libs/sodium_libs_sumo.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late SodiumCryptoService cryptoService;

  setUpAll(() async {
    cryptoService = SodiumCryptoService(await SodiumSumoInit.init());
  });

  test('an in-flight save cannot reopen a locked repository', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'pine_vault_lock_race_',
    );
    final fileService = _DelayedVaultFileService(
      directoryProvider: () async => temporaryDirectory,
    );
    final repository = VaultRepository(
      cryptoService: cryptoService,
      fileService: fileService,
      codec: const VaultCodec(),
    );
    addTearDown(() async {
      repository.lock();
      await temporaryDirectory.delete(recursive: true);
    });

    await repository.create('correct horse battery staple');
    fileService.delayNextWrite();
    final save = repository.upsert(
      title: 'Saved account',
      username: 'person@example.com',
      password: 'secret',
      url: '',
      notes: '',
      favorite: false,
    );
    await fileService.writeStarted.future;

    repository.lock();
    fileService.releaseWrite();
    await save;

    expect(repository.vault, isNull);
    expect(repository.currentVaultId, isNull);
  });

  test('sync configuration completion cannot override a lock', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'pine_vault_sync_lock_',
    );
    final repository = VaultRepository(
      cryptoService: cryptoService,
      fileService: VaultFileService(
        directoryProvider: () async => temporaryDirectory,
      ),
      codec: const VaultCodec(),
    );
    final syncVault = _DelayedSyncVaultUseCase();
    final viewModel = VaultViewModel(
      repository: repository,
      deviceUnlockService: DeviceUnlockService(),
      kdbxTransferService: KdbxTransferService(),
      syncVault: syncVault,
      restoreVault: _UnusedRestoreVaultUseCase(),
      syncHistoryService: SyncHistoryService(
        directoryProvider: () async => temporaryDirectory,
      ),
    );
    addTearDown(() async {
      viewModel.dispose();
      repository.lock();
      await temporaryDirectory.delete(recursive: true);
    });

    await viewModel.createVault('correct horse battery staple');
    final sync = viewModel.sync();
    await syncVault.configurationCheckStarted.future;

    viewModel.lock();
    syncVault.finishConfigurationCheck();

    expect(await sync, isFalse);
    expect(viewModel.state, VaultAppState.locked);
    expect(syncVault.syncCalls, 0);
  });
}

class _DelayedVaultFileService extends VaultFileService {
  _DelayedVaultFileService({required super.directoryProvider});

  Completer<void> writeStarted = Completer<void>();
  Completer<void> _writeRelease = Completer<void>();
  bool _delayNextWrite = false;

  void delayNextWrite() {
    _delayNextWrite = true;
    writeStarted = Completer<void>();
    _writeRelease = Completer<void>();
  }

  void releaseWrite() => _writeRelease.complete();

  @override
  Future<void> write(String contents) async {
    if (_delayNextWrite) {
      _delayNextWrite = false;
      writeStarted.complete();
      await _writeRelease.future;
    }
    await super.write(contents);
  }
}

class _DelayedSyncVaultUseCase implements SyncVaultUseCase {
  final configurationCheckStarted = Completer<void>();
  final _configurationCheckRelease = Completer<void>();
  int syncCalls = 0;

  @override
  Future<bool> isConfigured() async {
    configurationCheckStarted.complete();
    await _configurationCheckRelease.future;
    return true;
  }

  void finishConfigurationCheck() => _configurationCheckRelease.complete();

  @override
  Future<VaultSyncResult> call({
    bool forceUpload = false,
    void Function(VaultSyncStage stage)? onStage,
  }) async {
    syncCalls++;
    return const VaultSyncResult(
      outcome: VaultSyncOutcome.upToDate,
      conflictCount: 0,
    );
  }
}

class _UnusedRestoreVaultUseCase implements RestoreVaultUseCase {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
