import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../domain/models/webdav_configuration.dart';

class WebDavRemoteFile {
  const WebDavRemoteFile({required this.bytes, this.etag});

  final Uint8List bytes;
  final String? etag;
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

  Future<void> ensureVaultDirectory(
    WebDavCredentials credentials,
    String vaultId,
  ) async {
    for (final segments in [
      const ['Apps'],
      const ['Apps', 'PineVault'],
      ['Apps', 'PineVault', vaultId],
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

  Future<WebDavRemoteFile?> downloadVault(
    WebDavCredentials credentials,
    String vaultId,
  ) async {
    final response = await _send(
      method: 'GET',
      uri: _vaultUri(credentials.serverUri, vaultId),
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
    String vaultId,
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
      uri: _vaultUri(credentials.serverUri, vaultId),
      credentials: credentials,
      headers: headers,
      body: bytes,
    );
    await response.stream.drain<void>();
    _requireStatus(response, const {200, 201, 204});
    return response.headers[HttpHeaders.etagHeader];
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

  Uri _vaultUri(Uri baseUri, String vaultId) =>
      _resolve(baseUri, ['Apps', 'PineVault', vaultId, 'vault.pvlt']);

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
