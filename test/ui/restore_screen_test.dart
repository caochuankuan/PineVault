import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pine_vault/ui/features/onboarding/restore_screen.dart';

void main() {
  testWidgets('submits WebDAV and master-password restore fields', (
    tester,
  ) async {
    Map<String, String>? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: RestoreScreen(
          onRestore:
              ({
                required serverUrl,
                required username,
                required applicationPassword,
                required masterPassword,
              }) async {
                submitted = {
                  'serverUrl': serverUrl,
                  'username': username,
                  'applicationPassword': applicationPassword,
                  'masterPassword': masterPassword,
                };
                return 'test error';
              },
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('restore-username')),
      'person@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('restore-application-password')),
      'application-password',
    );
    await tester.enterText(
      find.byKey(const Key('restore-master-password')),
      'correct horse battery staple',
    );
    await tester.ensureVisible(find.byKey(const Key('restore-vault')));
    await tester.tap(find.byKey(const Key('restore-vault')));
    await tester.pump();

    expect(submitted?['serverUrl'], 'https://dav.jianguoyun.com/dav/');
    expect(submitted?['username'], 'person@example.com');
    expect(submitted?['applicationPassword'], 'application-password');
    expect(submitted?['masterPassword'], 'correct horse battery staple');
    expect(find.text('test error'), findsOneWidget);
  });
}
