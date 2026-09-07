import 'package:sodium_libs/sodium_libs_sumo.dart';

import '../data/repositories/vault_repository.dart';
import '../data/repositories/webdav_repository.dart';
import '../data/serialization/vault_codec.dart';
import '../data/services/crypto_service.dart';
import '../data/services/vault_file_service.dart';
import '../data/services/webdav_credential_store.dart';
import '../data/services/webdav_service.dart';
import '../ui/features/settings/webdav_settings_view_model.dart';
import '../ui/features/vault/vault_view_model.dart';

class AppDependencies {
  AppDependencies._({
    required this.vaultViewModel,
    required this.webDavSettingsViewModel,
  });

  final VaultViewModel vaultViewModel;
  final WebDavSettingsViewModel webDavSettingsViewModel;

  static Future<AppDependencies> create() async {
    final sodium = await SodiumSumoInit.init();
    final codec = const VaultCodec();
    final repository = VaultRepository(
      cryptoService: SodiumCryptoService(sodium),
      fileService: VaultFileService(),
      codec: codec,
    );
    return AppDependencies._(
      vaultViewModel: VaultViewModel(repository: repository),
      webDavSettingsViewModel: WebDavSettingsViewModel(
        repository: WebDavRepository(
          credentialStore: SecureWebDavCredentialStore(),
          service: WebDavService(),
        ),
      ),
    );
  }
}
