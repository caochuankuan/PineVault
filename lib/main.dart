import 'package:flutter/material.dart';

import 'app/app_dependencies.dart';
import 'app/autofill_app.dart';
import 'app/pine_vault_app.dart';
import 'data/services/native_autofill_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dependencies = await AppDependencies.create();
  await dependencies.vaultViewModel.initialize();
  runApp(
    PineVaultApp(
      vaultViewModel: dependencies.vaultViewModel,
      webDavSettingsViewModel: dependencies.webDavSettingsViewModel,
      backupViewModel: dependencies.backupViewModel,
    ),
  );
}

@pragma('vm:entry-point')
Future<void> autofillEntryPoint() async {
  WidgetsFlutterBinding.ensureInitialized();
  final request = await NativeAutofillAuth.request();
  final dependencies = await AppDependencies.create(enableVaultSync: false);
  await dependencies.vaultViewModel.initialize();
  runApp(
    AutofillApp(
      vaultViewModel: dependencies.vaultViewModel,
      request: request,
    ),
  );
}
