import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pine_vault/ui/features/onboarding/setup_screen.dart';

void main() {
  testWidgets('validates and submits matching master passwords', (
    tester,
  ) async {
    String? submittedPassword;
    await tester.pumpWidget(
      MaterialApp(
        home: SetupScreen(
          busy: false,
          onCreate: (password) async => submittedPassword = password,
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('master-password')), 'short');
    await tester.enterText(find.byKey(const Key('confirm-password')), 'short');
    await tester.tap(find.byKey(const Key('create-vault')));
    await tester.pump();
    expect(find.text('主密码至少需要 12 个字符'), findsOneWidget);
    expect(submittedPassword, isNull);

    const validPassword = 'correct horse battery staple';
    await tester.enterText(
      find.byKey(const Key('master-password')),
      validPassword,
    );
    await tester.enterText(
      find.byKey(const Key('confirm-password')),
      validPassword,
    );
    await tester.tap(find.byKey(const Key('create-vault')));
    await tester.pump();
    expect(submittedPassword, validPassword);
  });
}
