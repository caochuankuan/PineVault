import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ui/features/onboarding/setup_screen.dart';
import '../ui/features/backup/backup_view_model.dart';
import '../ui/features/settings/webdav_settings_view_model.dart';
import '../ui/features/unlock/unlock_screen.dart';
import '../ui/features/vault/vault_home_screen.dart';
import '../ui/features/vault/vault_view_model.dart';

class PineVaultApp extends StatefulWidget {
  const PineVaultApp({
    super.key,
    required this.vaultViewModel,
    required this.webDavSettingsViewModel,
    required this.backupViewModel,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final VaultViewModel vaultViewModel;
  final WebDavSettingsViewModel webDavSettingsViewModel;
  final BackupViewModel backupViewModel;
  final DateTime Function() _now;

  @override
  State<PineVaultApp> createState() => _PineVaultAppState();
}

class _PineVaultAppState extends State<PineVaultApp>
    with WidgetsBindingObserver {
  static const _backgroundLockDelay = Duration(seconds: 60);
  Timer? _backgroundLockTimer;
  DateTime? _backgroundedAt;
  bool _lockedForBackgroundTimeout = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _backgroundLockTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
        _scheduleBackgroundLock();
      case AppLifecycleState.resumed:
        _handleResumed();
      case AppLifecycleState.detached:
        break;
    }
  }

  void _scheduleBackgroundLock() {
    if (!_isVaultOpen) return;
    _backgroundedAt ??= widget._now();
    _backgroundLockTimer?.cancel();
    _backgroundLockTimer = Timer(_backgroundLockDelay, () {
      final backgroundedAt = _backgroundedAt;
      if (backgroundedAt == null ||
          widget._now().difference(backgroundedAt) < _backgroundLockDelay) {
        return;
      }
      if (_isVaultOpen) {
        _lockedForBackgroundTimeout = true;
        widget.vaultViewModel.lock(automaticDeviceUnlock: false);
      }
    });
  }

  void _handleResumed() {
    final backgroundedAt = _backgroundedAt;
    _backgroundedAt = null;
    _backgroundLockTimer?.cancel();
    _backgroundLockTimer = null;
    if (_lockedForBackgroundTimeout) {
      _lockedForBackgroundTimeout = false;
      widget.vaultViewModel.allowAutomaticDeviceUnlock();
      return;
    }
    if (backgroundedAt != null &&
        widget._now().difference(backgroundedAt) >= _backgroundLockDelay &&
        _isVaultOpen) {
      widget.vaultViewModel.lock();
    }
  }

  bool get _isVaultOpen => switch (widget.vaultViewModel.state) {
    VaultAppState.unlocked ||
    VaultAppState.saving ||
    VaultAppState.syncing => true,
    _ => false,
  };

  @override
  Widget build(BuildContext context) {
    final windowsFontFamily = defaultTargetPlatform == TargetPlatform.windows
        ? 'Microsoft YaHei UI'
        : null;
    final lightScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF176B52),
    );
    final darkScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF72D7B2),
      brightness: Brightness.dark,
    );
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.vaultViewModel),
        ChangeNotifierProvider.value(value: widget.webDavSettingsViewModel),
        ChangeNotifierProvider.value(value: widget.backupViewModel),
      ],
      child: MaterialApp(
        title: 'PineVault',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: lightScheme,
          fontFamily: windowsFontFamily,
          useMaterial3: true,
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: lightScheme.surfaceContainerLow,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
              borderSide: BorderSide(color: lightScheme.primary, width: 1.5),
            ),
          ),
        ),
        darkTheme: ThemeData(
          colorScheme: darkScheme,
          fontFamily: windowsFontFamily,
          useMaterial3: true,
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: darkScheme.surfaceContainerLow,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
              borderSide: BorderSide.none,
            ),
            enabledBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: const BorderRadius.all(Radius.circular(14)),
              borderSide: BorderSide(color: darkScheme.primary, width: 1.5),
            ),
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
            deviceUnlockEnabled: viewModel.deviceUnlockEnabled,
            onDeviceUnlock: viewModel.unlockWithDevice,
            automaticDeviceUnlock: viewModel.automaticDeviceUnlock,
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
