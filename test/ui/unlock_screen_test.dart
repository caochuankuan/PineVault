import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pine_vault/ui/features/unlock/unlock_screen.dart';

void main() {
  testWidgets('requests device authentication once when binding is enabled', (
    tester,
  ) async {
    var deviceUnlockCalls = 0;

    Widget buildScreen() => MaterialApp(
      home: UnlockScreen(
        busy: false,
        onUnlock: (_) async {},
        deviceUnlockEnabled: true,
        onDeviceUnlock: () async {
          deviceUnlockCalls++;
        },
      ),
    );

    await tester.pumpWidget(buildScreen());
    await tester.pump();
    expect(deviceUnlockCalls, 1);

    await tester.pumpWidget(buildScreen());
    await tester.pump();
    expect(deviceUnlockCalls, 1);
  });

  testWidgets('does not request device authentication without a binding', (
    tester,
  ) async {
    var deviceUnlockCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: UnlockScreen(
          busy: false,
          onUnlock: (_) async {},
          deviceUnlockEnabled: false,
          onDeviceUnlock: () async {
            deviceUnlockCalls++;
          },
        ),
      ),
    );
    await tester.pump();
    expect(deviceUnlockCalls, 0);
  });
}
