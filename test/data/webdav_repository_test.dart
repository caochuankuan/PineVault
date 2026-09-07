import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pine_vault/data/repositories/webdav_repository.dart';
import 'package:pine_vault/data/services/webdav_credential_store.dart';
import 'package:pine_vault/data/services/webdav_service.dart';
import 'package:pine_vault/domain/models/webdav_configuration.dart';

void main() {
  test('tests before storing normalized HTTPS credentials', () async {
    final store = _MemoryCredentialStore();
    final requests = <http.Request>[];
    final repository = WebDavRepository(
      credentialStore: store,
      service: WebDavService(
        client: MockClient((request) async {
          requests.add(request);
          return http.Response('', request.method == 'PROPFIND' ? 207 : 201);
        }),
      ),
    );

    await repository.testAndSave(
      serverUrl: 'https://dav.example.test/dav',
      username: ' person@example.com ',
      password: 'application-password',
      vaultId: 'vault-id',
    );

    expect(
      store.credentials?.serverUri.toString(),
      'https://dav.example.test/dav/',
    );
    expect(store.credentials?.username, 'person@example.com');
    expect(store.credentials?.password, 'application-password');
    expect(requests.map((request) => request.method), [
      'PROPFIND',
      'MKCOL',
      'MKCOL',
      'MKCOL',
    ]);
  });

  test(
    'does not replace saved credentials when connection testing fails',
    () async {
      final original = WebDavCredentials(
        serverUri: Uri.parse('https://dav.example.test/dav/'),
        username: 'old@example.com',
        password: 'old-password',
      );
      final store = _MemoryCredentialStore()..credentials = original;
      final repository = WebDavRepository(
        credentialStore: store,
        service: WebDavService(
          client: MockClient((_) async => http.Response('', 401)),
        ),
      );

      await expectLater(
        repository.testAndSave(
          serverUrl: 'https://dav.example.test/dav/',
          username: 'new@example.com',
          password: 'new-password',
          vaultId: 'vault-id',
        ),
        throwsA(isA<WebDavException>()),
      );
      expect(store.credentials, same(original));
    },
  );

  test('rejects insecure WebDAV URLs', () async {
    final repository = WebDavRepository(
      credentialStore: _MemoryCredentialStore(),
      service: WebDavService(
        client: MockClient((_) async => http.Response('', 207)),
      ),
    );

    await expectLater(
      repository.testAndSave(
        serverUrl: 'http://dav.example.test/dav/',
        username: 'person@example.com',
        password: 'application-password',
        vaultId: 'vault-id',
      ),
      throwsA(isA<FormatException>()),
    );
  });
}

class _MemoryCredentialStore implements WebDavCredentialStore {
  WebDavCredentials? credentials;

  @override
  Future<void> clear() async => credentials = null;

  @override
  Future<WebDavCredentials?> read() async => credentials;

  @override
  Future<void> write(WebDavCredentials value) async => credentials = value;
}
