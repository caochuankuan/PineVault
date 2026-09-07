import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ui/features/onboarding/setup_screen.dart';
import '../ui/features/unlock/unlock_screen.dart';
import '../ui/features/vault/vault_home_screen.dart';
import '../ui/features/vault/vault_view_model.dart';

class PineVaultApp extends StatelessWidget {
  const PineVaultApp({super.key, required this.viewModel});

  final VaultViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: viewModel,
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
          VaultAppState.noVault || VaultAppState.creating => SetupScreen(
            busy: viewModel.state == VaultAppState.creating,
            errorMessage: viewModel.errorMessage,
            onCreate: viewModel.createVault,
          ),
          VaultAppState.locked || VaultAppState.unlocking => UnlockScreen(
            busy: viewModel.state == VaultAppState.unlocking,
            errorMessage: viewModel.errorMessage,
            onUnlock: viewModel.unlock,
          ),
          VaultAppState.unlocked ||
          VaultAppState.saving => const VaultHomeScreen(),
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
