import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pine_vault/data/services/webdav_credential_store.dart';
import 'package:pine_vault/domain/models/webdav_configuration.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('stores WebDAV credentials in platform secure storage', (
    tester,
  ) async {
    final store = SecureWebDavCredentialStore(
      credentialsKey: 'webdav.credentials.integration_test',
    );
    addTearDown(store.clear);
    await store.clear();

    final credentials = WebDavCredentials(
      serverUri: Uri.parse('https://dav.example.test/dav/'),
      username: 'integration@example.com',
      password: 'integration-application-password',
    );
    await store.write(credentials);
    final restored = await store.read();

    expect(restored?.serverUri, credentials.serverUri);
    expect(restored?.username, credentials.username);
    expect(restored?.password, credentials.password);
  });
}
