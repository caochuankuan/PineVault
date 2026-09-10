import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../../domain/models/webdav_configuration.dart';

class WebDavRemoteFile {
  const WebDavRemoteFile({required this.bytes, this.etag});

  final Uint8List bytes;
  final String? etag;
}

class WebDavBackupFile {
  const WebDavBackupFile({
    required this.name,
    required this.size,
    required this.createdAt,
  });

  final String name;
  final int size;
  final DateTime createdAt;
}

class WebDavException implements Exception {
  const WebDavException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class WebDavService {
  WebDavService({http.Client? client, Duration? timeout})
    : _client = client ?? http.Client(),
      _timeout = timeout ?? const Duration(seconds: 15);

  final http.Client _client;
  final Duration _timeout;

  Future<void> testConnection(WebDavCredentials credentials) async {
    final response = await _send(
      method: 'PROPFIND',
      uri: credentials.serverUri,
      credentials: credentials,
      headers: const {'Depth': '0'},
    );
    await response.stream.drain<void>();
    _requireStatus(response, const {200, 207});
  }

  Future<void> ensureVaultDirectory(WebDavCredentials credentials) async {
    for (final segments in [
      const ['Apps'],
      const ['Apps', 'PineVault'],
    ]) {
      final response = await _send(
        method: 'MKCOL',
        uri: _resolve(credentials.serverUri, segments, directory: true),
        credentials: credentials,
      );
      await response.stream.drain<void>();
      _requireStatus(response, const {201, 405});
    }
  }

  Future<WebDavRemoteFile?> downloadVault(WebDavCredentials credentials) async {
    final response = await _send(
      method: 'GET',
      uri: _vaultUri(credentials.serverUri),
      credentials: credentials,
    );
    if (response.statusCode == 404) {
      await response.stream.drain<void>();
      return null;
    }
    if (response.statusCode != 200) {
      await response.stream.drain<void>();
    }
    _requireStatus(response, const {200});
    return WebDavRemoteFile(
      bytes: await response.stream.toBytes(),
      etag: response.headers[HttpHeaders.etagHeader],
    );
  }

  Future<String?> uploadVault(
    WebDavCredentials credentials,
    List<int> bytes, {
    String? expectedEtag,
    bool createOnly = false,
  }) async {
    final headers = <String, String>{
      HttpHeaders.contentTypeHeader: 'application/octet-stream',
    };
    if (expectedEtag case final etag?) {
      headers[HttpHeaders.ifMatchHeader] = etag;
    }
    if (createOnly) headers[HttpHeaders.ifNoneMatchHeader] = '*';
    final response = await _send(
      method: 'PUT',
      uri: _vaultUri(credentials.serverUri),
      credentials: credentials,
      headers: headers,
      body: bytes,
    );
    await response.stream.drain<void>();
    _requireStatus(response, const {200, 201, 204});
    return response.headers[HttpHeaders.etagHeader];
  }

  Future<void> ensureBackupDirectory(
    WebDavCredentials credentials,
    String vaultId,
  ) async {
    await ensureVaultDirectory(credentials);
    final backupsResponse = await _send(
      method: 'MKCOL',
      uri: _backupsUri(credentials.serverUri),
      credentials: credentials,
    );
    await backupsResponse.stream.drain<void>();
    _requireStatus(backupsResponse, const {201, 405});
    final vaultResponse = await _send(
      method: 'MKCOL',
      uri: _backupUri(credentials.serverUri, vaultId),
      credentials: credentials,
    );
    await vaultResponse.stream.drain<void>();
    _requireStatus(vaultResponse, const {201, 405});
  }

  Future<List<WebDavBackupFile>> listBackups(
    WebDavCredentials credentials,
    String vaultId,
  ) async {
    final response = await _send(
      method: 'PROPFIND',
      uri: _backupUri(credentials.serverUri, vaultId),
      credentials: credentials,
      headers: const {'Depth': '1'},
    );
    if (response.statusCode == 404) {
      await response.stream.drain<void>();
      return const [];
    }
    _requireStatus(response, const {200, 207});
    final document = XmlDocument.parse(await response.stream.bytesToString());
    final files = <WebDavBackupFile>[];
    for (final element in document.findAllElements(
      'response',
      namespace: '*',
    )) {
      final href = element.findAllElements('href', namespace: '*').firstOrNull;
      if (href == null) continue;
      final name = Uri.decodeComponent(
        Uri.parse(href.innerText).pathSegments.lastOrNull ?? '',
      );
      if (!name.endsWith('.pvlt')) continue;
      final length = element
          .findAllElements('getcontentlength', namespace: '*')
          .firstOrNull
          ?.innerText;
      final modified = element
          .findAllElements('getlastmodified', namespace: '*')
          .firstOrNull
          ?.innerText;
      files.add(
        WebDavBackupFile(
          name: name,
          size: int.tryParse(length ?? '') ?? 0,
          createdAt: _httpDate(modified) ?? _dateFromBackupName(name),
        ),
      );
    }
    files.sort((a, b) => b.name.compareTo(a.name));
    return files;
  }

  Future<void> uploadBackup(
    WebDavCredentials credentials,
    String vaultId,
    String name,
    List<int> bytes,
  ) async {
    final response = await _send(
      method: 'PUT',
      uri: _backupUri(credentials.serverUri, vaultId, name),
      credentials: credentials,
      headers: const {
        HttpHeaders.contentTypeHeader: 'application/octet-stream',
        HttpHeaders.ifNoneMatchHeader: '*',
      },
      body: bytes,
    );
    await response.stream.drain<void>();
    _requireStatus(response, const {200, 201, 204});
  }

  Future<WebDavRemoteFile> downloadBackup(
    WebDavCredentials credentials,
    String vaultId,
    String name,
  ) async {
    final response = await _send(
      method: 'GET',
      uri: _backupUri(credentials.serverUri, vaultId, name),
      credentials: credentials,
    );
    _requireStatus(response, const {200});
    return WebDavRemoteFile(
      bytes: await response.stream.toBytes(),
      etag: response.headers[HttpHeaders.etagHeader],
    );
  }

  Future<void> deleteBackup(
    WebDavCredentials credentials,
    String vaultId,
    String name,
  ) async {
    final response = await _send(
      method: 'DELETE',
      uri: _backupUri(credentials.serverUri, vaultId, name),
      credentials: credentials,
    );
    await response.stream.drain<void>();
    _requireStatus(response, const {200, 204, 404});
  }

  Future<http.StreamedResponse> _send({
    required String method,
    required Uri uri,
    required WebDavCredentials credentials,
    Map<String, String> headers = const {},
    List<int>? body,
  }) async {
    final authorization = base64Encode(
      utf8.encode('${credentials.username}:${credentials.password}'),
    );
    final request = http.Request(method, uri)
      ..headers.addAll({
        HttpHeaders.authorizationHeader: 'Basic $authorization',
        HttpHeaders.acceptHeader: '*/*',
        ...headers,
      });
    if (body != null) request.bodyBytes = body;
    try {
      return await _client.send(request).timeout(_timeout);
    } on TimeoutException {
      throw const WebDavException('连接超时，请检查网络和服务器地址');
    } on http.ClientException {
      throw const WebDavException('无法连接 WebDAV 服务器');
    }
  }

  Uri _vaultUri(Uri baseUri) =>
      _resolve(baseUri, const ['Apps', 'PineVault', 'vault.pvlt']);

  Uri _backupsUri(Uri baseUri) => _resolve(baseUri, const [
    'Apps',
    'PineVault',
    'backups',
  ], directory: true);

  Uri _backupUri(Uri baseUri, String vaultId, [String? name]) => _resolve(
    baseUri,
    ['Apps', 'PineVault', 'backups', vaultId, ?name],
    directory: name == null,
  );

  Uri _resolve(Uri baseUri, List<String> extra, {bool directory = false}) {
    final baseSegments = baseUri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList(growable: true);
    baseSegments.addAll(extra);
    if (directory) baseSegments.add('');
    return baseUri.replace(
      pathSegments: baseSegments,
      query: null,
      fragment: null,
    );
  }

  void _requireStatus(http.StreamedResponse response, Set<int> accepted) {
    if (accepted.contains(response.statusCode)) return;
    throw WebDavException(
      _messageForStatus(response.statusCode),
      statusCode: response.statusCode,
    );
  }

  DateTime? _httpDate(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return HttpDate.parse(value).toUtc();
    } on FormatException {
      return null;
    }
  }

  DateTime _dateFromBackupName(String name) {
    final match = RegExp(r'(\d{8})(?:-(\d{6}))?').firstMatch(name);
    if (match == null) {
      return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }
    final date = match.group(1)!;
    final time = match.group(2) ?? '000000';
    return DateTime.utc(
      int.parse(date.substring(0, 4)),
      int.parse(date.substring(4, 6)),
      int.parse(date.substring(6, 8)),
      int.parse(time.substring(0, 2)),
      int.parse(time.substring(2, 4)),
      int.parse(time.substring(4, 6)),
    );
  }

  String _messageForStatus(int statusCode) => switch (statusCode) {
    401 => '认证失败，请使用坚果云第三方应用密码',
    403 => '服务器拒绝访问，请检查 WebDAV 权限',
    404 => 'WebDAV 地址或远端文件不存在',
    409 => '远端父目录不存在',
    412 => '远端密码库已变化，需要先下载并合并',
    507 => 'WebDAV 存储空间不足',
    _ => 'WebDAV 请求失败（HTTP $statusCode）',
  };
}
