import 'package:sodium_libs/sodium_libs_sumo.dart';

import '../data/repositories/vault_repository.dart';
import '../data/repositories/backup_repository.dart';
import '../data/repositories/webdav_repository.dart';
import '../data/serialization/vault_codec.dart';
import '../data/services/crypto_service.dart';
import '../data/services/backup_state_service.dart';
import '../data/services/local_backup_service.dart';
import '../data/services/device_unlock_service.dart';
import '../data/services/kdbx_transfer_service.dart';
import '../data/services/sync_state_service.dart';
import '../data/services/sync_history_service.dart';
import '../data/services/vault_file_service.dart';
import '../data/services/webdav_credential_store.dart';
import '../data/services/webdav_service.dart';
import '../domain/use_cases/restore_vault_use_case.dart';
import '../domain/use_cases/sync_vault_use_case.dart';
import '../domain/use_cases/vault_merge_service.dart';
import '../ui/features/settings/webdav_settings_view_model.dart';
import '../ui/features/backup/backup_view_model.dart';
import '../ui/features/vault/vault_view_model.dart';

class AppDependencies {
  AppDependencies._({
    required this.vaultViewModel,
    required this.webDavSettingsViewModel,
    required this.backupViewModel,
  });

  final VaultViewModel vaultViewModel;
  final WebDavSettingsViewModel webDavSettingsViewModel;
  final BackupViewModel backupViewModel;

  static Future<AppDependencies> create({bool enableVaultSync = true}) async {
    final sodium = await SodiumSumoInit.init();
    final codec = const VaultCodec();
    final repository = VaultRepository(
      cryptoService: SodiumCryptoService(sodium),
      fileService: VaultFileService(),
      codec: codec,
    );
    final webDavRepository = WebDavRepository(
      credentialStore: VaultWebDavCredentialStore(repository),
      service: WebDavService(),
    );
    final syncStateService = SyncStateService();
    final syncVault = SyncVaultUseCase(
      vaultRepository: repository,
      webDavRepository: webDavRepository,
      stateService: syncStateService,
      mergeService: VaultMergeService(),
    );
    final restoreVault = RestoreVaultUseCase(
      vaultRepository: repository,
      webDavRepository: webDavRepository,
      stateService: syncStateService,
    );
    final backupRepository = BackupRepository(
      vaultRepository: repository,
      webDavRepository: webDavRepository,
      localService: LocalBackupService(),
      stateService: BackupStateService(),
      syncStateService: syncStateService,
    );
    final vaultViewModel = VaultViewModel(
      repository: repository,
      deviceUnlockService: DeviceUnlockService(),
      kdbxTransferService: KdbxTransferService(),
      syncVault: syncVault,
      restoreVault: restoreVault,
      syncHistoryService: SyncHistoryService(),
      enableVaultSync: enableVaultSync,
    );
    return AppDependencies._(
      vaultViewModel: vaultViewModel,
      webDavSettingsViewModel: WebDavSettingsViewModel(
        repository: webDavRepository,
        onConfigurationSaved: vaultViewModel.requestAutoSync,
      ),
      backupViewModel: BackupViewModel(
        repository: backupRepository,
        vaultViewModel: vaultViewModel,
      ),
    );
  }
}
