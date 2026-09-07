import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pine_vault/data/services/webdav_service.dart';
import 'package:pine_vault/domain/models/webdav_configuration.dart';

void main() {
  const username = 'person@example.com';
  const password = 'application-password';
  final credentials = WebDavCredentials(
    serverUri: Uri.parse('https://dav.example.test/dav/'),
    username: username,
    password: password,
  );

  test('tests a connection with PROPFIND and Basic authentication', () async {
    late http.Request captured;
    final service = WebDavService(
      client: MockClient((request) async {
        captured = request;
        return http.Response('', 207);
      }),
    );

    await service.testConnection(credentials);

    expect(captured.method, 'PROPFIND');
    expect(captured.url.toString(), 'https://dav.example.test/dav/');
    expect(captured.headers['Depth'], '0');
    expect(
      captured.headers['authorization'],
      'Basic ${base64Encode(utf8.encode('$username:$password'))}',
    );
  });

  test('creates the remote vault directory one level at a time', () async {
    final requests = <http.Request>[];
    final service = WebDavService(
      client: MockClient((request) async {
        requests.add(request);
        return http.Response('', 201);
      }),
    );

    await service.ensureVaultDirectory(credentials, 'vault id');

    expect(requests.map((request) => request.method), everyElement('MKCOL'));
    expect(requests.map((request) => request.url.toString()), [
      'https://dav.example.test/dav/Apps/',
      'https://dav.example.test/dav/Apps/PineVault/',
      'https://dav.example.test/dav/Apps/PineVault/vault%20id/',
    ]);
  });

  test('uploads with an ETag precondition and returns the new ETag', () async {
    late http.Request captured;
    final service = WebDavService(
      client: MockClient((request) async {
        captured = request;
        return http.Response('', 204, headers: {'etag': '"new"'});
      }),
    );

    final etag = await service.uploadVault(credentials, 'vault-id', [
      1,
      2,
      3,
    ], expectedEtag: '"old"');

    expect(captured.method, 'PUT');
    expect(captured.url.path, '/dav/Apps/PineVault/vault-id/vault.pvlt');
    expect(captured.headers['if-match'], '"old"');
    expect(captured.bodyBytes, [1, 2, 3]);
    expect(etag, '"new"');
  });

  test('downloads encrypted bytes and ETag', () async {
    final service = WebDavService(
      client: MockClient(
        (_) async => http.Response.bytes(
          Uint8List.fromList([4, 5, 6]),
          200,
          headers: {'etag': '"remote"'},
        ),
      ),
    );

    final remote = await service.downloadVault(credentials, 'vault-id');

    expect(remote?.bytes, [4, 5, 6]);
    expect(remote?.etag, '"remote"');
  });

  test(
    'maps authentication failures without exposing a response body',
    () async {
      final service = WebDavService(
        client: MockClient(
          (_) async => http.Response('server-secret-details', 401),
        ),
      );

      expect(
        () => service.testConnection(credentials),
        throwsA(
          isA<WebDavException>()
              .having((error) => error.statusCode, 'statusCode', 401)
              .having(
                (error) => error.toString(),
                'message',
                isNot(contains('server-secret-details')),
              ),
        ),
      );
    },
  );
}
