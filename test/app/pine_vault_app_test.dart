import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pine_vault/app/pine_vault_app.dart';
import 'package:pine_vault/ui/features/backup/backup_view_model.dart';
import 'package:pine_vault/domain/models/vault_group.dart';
import 'package:pine_vault/domain/models/vault_item.dart';
import 'package:pine_vault/ui/features/settings/webdav_settings_view_model.dart';
import 'package:pine_vault/ui/features/vault/vault_view_model.dart';

void main() {
  testWidgets('shows the selected item in the desktop detail pane', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime(2026);
    final vaultViewModel = _FakeVaultViewModel(
      items: [
        VaultItem(
          id: 'desktop-item',
          type: VaultItemType.login,
          title: '桌面测试条目',
          username: 'desktop-user',
          password: 'desktop-password',
          urls: const ['example.com'],
          notes: '',
          favorite: false,
          createdAt: now,
          updatedAt: now,
          revision: 1,
        ),
      ],
    );
    await tester.pumpWidget(
      PineVaultApp(
        vaultViewModel: vaultViewModel,
        webDavSettingsViewModel: _FakeWebDavSettingsViewModel(),
        backupViewModel: _FakeBackupViewModel(),
      ),
    );

    expect(find.text('选择一个条目，或创建新密码'), findsOneWidget);
    final addButton = find.byKey(const Key('add-item'));
    expect(addButton, findsOneWidget);
    expect(
      find.ancestor(of: addButton, matching: find.byType(AppBar)),
      findsOneWidget,
    );
    expect(
      find.ancestor(of: addButton, matching: find.byType(FloatingActionButton)),
      findsNothing,
    );
    await tester.tap(find.text('桌面测试条目'));
    await tester.pump();

    expect(find.text('选择一个条目，或创建新密码'), findsNothing);
    expect(find.text('密码'), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets(
    'locks after 60 background seconds and authenticates only after resume',
    (tester) async {
      final vaultViewModel = _FakeVaultViewModel();
      var now = DateTime(2026);
      await tester.pumpWidget(
        PineVaultApp(
          vaultViewModel: vaultViewModel,
          webDavSettingsViewModel: _FakeWebDavSettingsViewModel(),
          backupViewModel: _FakeBackupViewModel(),
          now: () => now,
        ),
      );

      _sendToBackground(tester);
      now = now.add(const Duration(seconds: 59));
      await tester.pump(const Duration(seconds: 59));
      expect(vaultViewModel.lockCalls, 0);

      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(vaultViewModel.lockCalls, 1);
      expect(vaultViewModel.state, VaultAppState.locked);
      expect(vaultViewModel.automaticDeviceUnlock, isFalse);
      expect(vaultViewModel.deviceUnlockCalls, 0);

      _resume(tester);
      await tester.pump();
      await tester.pump();
      expect(vaultViewModel.automaticDeviceUnlock, isTrue);
      expect(vaultViewModel.deviceUnlockCalls, 1);
    },
  );

  testWidgets('does not lock after a short background visit', (tester) async {
    final vaultViewModel = _FakeVaultViewModel();
    var now = DateTime(2026);
    await tester.pumpWidget(
      PineVaultApp(
        vaultViewModel: vaultViewModel,
        webDavSettingsViewModel: _FakeWebDavSettingsViewModel(),
        backupViewModel: _FakeBackupViewModel(),
        now: () => now,
      ),
    );

    _sendToBackground(tester);
    now = now.add(const Duration(seconds: 30));
    await tester.pump(const Duration(seconds: 30));
    _resume(tester);
    await tester.pump();

    expect(vaultViewModel.lockCalls, 0);
    expect(vaultViewModel.state, VaultAppState.unlocked);
  });
}

class _FakeBackupViewModel extends ChangeNotifier implements BackupViewModel {
  @override
  String? get message => null;

  @override
  Future<bool> checkAutomatic() async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void _sendToBackground(WidgetTester tester) {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
}

void _resume(WidgetTester tester) {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
}

class _FakeVaultViewModel extends ChangeNotifier implements VaultViewModel {
  _FakeVaultViewModel({this.items = const []});

  @override
  final List<VaultItem> items;

  VaultAppState _state = VaultAppState.unlocked;
  bool _automaticDeviceUnlock = true;
  int lockCalls = 0;
  int deviceUnlockCalls = 0;

  @override
  VaultAppState get state => _state;

  @override
  bool get automaticDeviceUnlock => _automaticDeviceUnlock;

  @override
  bool get deviceUnlockEnabled => true;

  @override
  String? get errorMessage => null;

  @override
  bool get busy => false;

  @override
  bool get deviceUnlockSupported => true;

  @override
  bool get deviceUnlockBusy => false;

  @override
  bool get showPasswords => false;

  @override
  bool get showWebsites => false;

  @override
  bool get showTotp => false;

  @override
  bool get shouldShowTotp => false;

  @override
  VaultSortOrder get sortOrder => VaultSortOrder.name;

  @override
  bool get sortReversed => false;

  @override
  String get query => '';

  @override
  String get selectedGroupId => 'all';

  @override
  bool get selectionMode => false;

  @override
  List<VaultGroup> get groups => const [];

  @override
  Set<String> get selectedItemIds => const {};

  @override
  List<VaultItem> get selectedItems => const [];

  @override
  String? get syncMessage => null;

  @override
  String? get syncProgress => null;

  @override
  bool get webDavConflict => false;

  @override
  void lock({bool automaticDeviceUnlock = true}) {
    lockCalls++;
    _automaticDeviceUnlock = automaticDeviceUnlock;
    _state = VaultAppState.locked;
    notifyListeners();
  }

  @override
  void allowAutomaticDeviceUnlock() {
    _automaticDeviceUnlock = true;
    notifyListeners();
  }

  @override
  Future<void> unlock(String masterPassword) async {}

  @override
  Future<void> unlockWithDevice() async {
    deviceUnlockCalls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeWebDavSettingsViewModel extends ChangeNotifier
    implements WebDavSettingsViewModel {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
