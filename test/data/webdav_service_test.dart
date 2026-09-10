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

    await service.ensureVaultDirectory(credentials);

    expect(requests.map((request) => request.method), everyElement('MKCOL'));
    expect(requests.map((request) => request.url.toString()), [
      'https://dav.example.test/dav/Apps/',
      'https://dav.example.test/dav/Apps/PineVault/',
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

    final etag = await service.uploadVault(credentials, [
      1,
      2,
      3,
    ], expectedEtag: '"old"');

    expect(captured.method, 'PUT');
    expect(captured.url.path, '/dav/Apps/PineVault/vault.pvlt');
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

    final remote = await service.downloadVault(credentials);

    expect(remote?.bytes, [4, 5, 6]);
    expect(remote?.etag, '"remote"');
  });

  test('lists WebDAV backup files from a multistatus response', () async {
    final service = WebDavService(
      client: MockClient(
        (_) async => http.Response('''<?xml version="1.0"?>
<d:multistatus xmlns:d="DAV:">
  <d:response><d:href>/dav/Apps/PineVault/backups/vault-id/</d:href></d:response>
  <d:response><d:href>/dav/Apps/PineVault/backups/vault-id/auto-20260910-120000.pvlt</d:href><d:propstat><d:prop><d:getcontentlength>123</d:getcontentlength><d:getlastmodified>Thu, 10 Sep 2026 12:34:56 GMT</d:getlastmodified></d:prop></d:propstat></d:response>
</d:multistatus>''', 207),
      ),
    );

    final backups = await service.listBackups(credentials, 'vault-id');

    expect(backups, hasLength(1));
    expect(backups.single.name, 'auto-20260910-120000.pvlt');
    expect(backups.single.size, 123);
    expect(backups.single.createdAt, DateTime.utc(2026, 9, 10, 12, 34, 56));
  });

  test('uploads a backup without allowing replacement', () async {
    late http.Request captured;
    final service = WebDavService(
      client: MockClient((request) async {
        captured = request;
        return http.Response('', 201);
      }),
    );

    await service.uploadBackup(
      credentials,
      'vault-id',
      'manual-20260910-120000.pvlt',
      [1, 2],
    );

    expect(captured.method, 'PUT');
    expect(captured.headers['if-none-match'], '*');
    expect(
      captured.url.path,
      '/dav/Apps/PineVault/backups/vault-id/manual-20260910-120000.pvlt',
    );
  });

  test(
    'creates shared and vault backup directories one level at a time',
    () async {
      final requests = <http.Request>[];
      final service = WebDavService(
        client: MockClient((request) async {
          requests.add(request);
          return http.Response('', 201);
        }),
      );

      await service.ensureBackupDirectory(credentials, 'vault-id');

      expect(requests.map((request) => request.url.path), [
        '/dav/Apps/',
        '/dav/Apps/PineVault/',
        '/dav/Apps/PineVault/backups/',
        '/dav/Apps/PineVault/backups/vault-id/',
      ]);
    },
  );

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
