import 'package:flutter/material.dart';

import 'app/app_dependencies.dart';
import 'app/pine_vault_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dependencies = await AppDependencies.create();
  await dependencies.vaultViewModel.initialize();
  runApp(PineVaultApp(viewModel: dependencies.vaultViewModel));
}
