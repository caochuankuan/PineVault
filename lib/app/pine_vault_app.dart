import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ui/features/onboarding/setup_screen.dart';
import '../ui/features/settings/webdav_settings_view_model.dart';
import '../ui/features/unlock/unlock_screen.dart';
import '../ui/features/vault/vault_home_screen.dart';
import '../ui/features/vault/vault_view_model.dart';

class PineVaultApp extends StatefulWidget {
  const PineVaultApp({
    super.key,
    required this.vaultViewModel,
    required this.webDavSettingsViewModel,
  });

  final VaultViewModel vaultViewModel;
  final WebDavSettingsViewModel webDavSettingsViewModel;

  @override
  State<PineVaultApp> createState() => _PineVaultAppState();
}

class _PineVaultAppState extends State<PineVaultApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.vaultViewModel.onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.vaultViewModel),
        ChangeNotifierProvider.value(value: widget.webDavSettingsViewModel),
      ],
      child: MaterialApp(
        title: 'PineVault',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF176B52)),
          useMaterial3: true,
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
          ),
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF72D7B2),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
          ),
        ),
        home: const _AppRouter(),
      ),
    );
  }
}

class _AppRouter extends StatelessWidget {
  const _AppRouter();

  @override
  Widget build(BuildContext context) {
    return Consumer<VaultViewModel>(
      builder: (context, viewModel, _) {
        return switch (viewModel.state) {
          VaultAppState.initializing => const _LoadingScreen(),
          VaultAppState.noVault ||
          VaultAppState.creating ||
          VaultAppState.restoring => SetupScreen(
            busy:
                viewModel.state == VaultAppState.creating ||
                viewModel.state == VaultAppState.restoring,
            errorMessage: viewModel.errorMessage,
            onCreate: viewModel.createVault,
            onRestore: viewModel.restore,
          ),
          VaultAppState.locked || VaultAppState.unlocking => UnlockScreen(
            busy: viewModel.state == VaultAppState.unlocking,
            errorMessage: viewModel.errorMessage,
            onUnlock: viewModel.unlock,
          ),
          VaultAppState.unlocked ||
          VaultAppState.saving ||
          VaultAppState.syncing => const VaultHomeScreen(),
        };
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
