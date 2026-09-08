import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../domain/models/totp_config.dart';

class TotpService {
  const TotpService();

  TotpConfig parse(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) throw const FormatException('请输入动态验证码密钥');
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.scheme.toLowerCase() == 'otpauth') {
      return _parseUri(uri);
    }
    return TotpConfig(secret: normalizeSecret(trimmed));
  }

  TotpConfig _parseUri(Uri uri) {
    if (uri.host.toLowerCase() != 'totp') {
      throw const FormatException('暂不支持 HOTP，只支持 TOTP');
    }
    final secret = uri.queryParameters['secret'];
    if (secret == null || secret.trim().isEmpty) {
      throw const FormatException('动态验证码地址缺少密钥');
    }
    final digits = int.tryParse(uri.queryParameters['digits'] ?? '6');
    if (digits != 6 && digits != 8) {
      throw const FormatException('动态验证码位数只支持 6 或 8');
    }
    final period = int.tryParse(uri.queryParameters['period'] ?? '30');
    if (period == null || period <= 0) {
      throw const FormatException('动态验证码周期无效');
    }
    final algorithm = _parseAlgorithm(
      uri.queryParameters['algorithm'] ?? 'SHA1',
    );
    final label = uri.pathSegments.isEmpty ? '' : uri.pathSegments.join('/');
    final issuer = (uri.queryParameters['issuer'] ?? '').trim();
    var account = label.trim();
    if (issuer.isNotEmpty && account.startsWith('$issuer:')) {
      account = account.substring(issuer.length + 1).trim();
    } else if (account.contains(':')) {
      account = account.substring(account.indexOf(':') + 1).trim();
    }
    return TotpConfig(
      secret: normalizeSecret(secret),
      algorithm: algorithm,
      digits: digits!,
      period: period,
      issuer: issuer,
      account: account,
    );
  }

  TotpAlgorithm _parseAlgorithm(String value) {
    return switch (value.trim().toUpperCase().replaceAll('-', '')) {
      'SHA1' => TotpAlgorithm.sha1,
      'SHA256' => TotpAlgorithm.sha256,
      'SHA512' => TotpAlgorithm.sha512,
      _ => throw const FormatException('不支持该动态验证码算法'),
    };
  }

  String normalizeSecret(String value) {
    final normalized = value.toUpperCase().replaceAll(RegExp(r'[\s\-=]'), '');
    if (normalized.isEmpty || !RegExp(r'^[A-Z2-7]+$').hasMatch(normalized)) {
      throw const FormatException('动态验证码密钥不是有效的 Base32');
    }
    _decodeBase32(normalized);
    return normalized;
  }

  String generate(TotpConfig config, {DateTime? time}) {
    final secret = _decodeBase32(normalizeSecret(config.secret));
    final seconds =
        (time ?? DateTime.now()).toUtc().millisecondsSinceEpoch ~/ 1000;
    final counter = seconds ~/ config.period;
    final counterBytes = ByteData(8)..setUint64(0, counter, Endian.big);
    final digest = Hmac(
      _hashFor(config.algorithm),
      secret,
    ).convert(counterBytes.buffer.asUint8List()).bytes;
    final offset = digest.last & 0x0f;
    final binary =
        ((digest[offset] & 0x7f) << 24) |
        ((digest[offset + 1] & 0xff) << 16) |
        ((digest[offset + 2] & 0xff) << 8) |
        (digest[offset + 3] & 0xff);
    final modulo = config.digits == 8 ? 100000000 : 1000000;
    return (binary % modulo).toString().padLeft(config.digits, '0');
  }

  int remainingSeconds(TotpConfig config, {DateTime? time}) {
    final seconds =
        (time ?? DateTime.now()).toUtc().millisecondsSinceEpoch ~/ 1000;
    final elapsed = seconds % config.period;
    return elapsed == 0 ? config.period : config.period - elapsed;
  }

  Uri toUri(TotpConfig config) {
    final issuer = config.issuer.trim();
    final account = config.account.trim();
    final label = issuer.isEmpty
        ? account
        : account.isEmpty
        ? issuer
        : '$issuer:$account';
    return Uri(
      scheme: 'otpauth',
      host: 'totp',
      pathSegments: [label.isEmpty ? '松匣' : label],
      queryParameters: {
        'secret': normalizeSecret(config.secret),
        if (issuer.isNotEmpty) 'issuer': issuer,
        'algorithm': _algorithmName(config.algorithm),
        'digits': config.digits.toString(),
        'period': config.period.toString(),
      },
    );
  }

  Hash _hashFor(TotpAlgorithm algorithm) => switch (algorithm) {
    TotpAlgorithm.sha1 => sha1,
    TotpAlgorithm.sha256 => sha256,
    TotpAlgorithm.sha512 => sha512,
  };

  String _algorithmName(TotpAlgorithm algorithm) => switch (algorithm) {
    TotpAlgorithm.sha1 => 'SHA1',
    TotpAlgorithm.sha256 => 'SHA256',
    TotpAlgorithm.sha512 => 'SHA512',
  };

  Uint8List _decodeBase32(String input) {
    var buffer = 0;
    var bitsLeft = 0;
    final output = <int>[];
    for (final codeUnit in input.codeUnits) {
      final value = codeUnit >= 65 && codeUnit <= 90
          ? codeUnit - 65
          : codeUnit >= 50 && codeUnit <= 55
          ? codeUnit - 24
          : -1;
      if (value < 0) throw const FormatException('动态验证码密钥不是有效的 Base32');
      buffer = (buffer << 5) | value;
      bitsLeft += 5;
      if (bitsLeft >= 8) {
        bitsLeft -= 8;
        output.add((buffer >> bitsLeft) & 0xff);
        buffer &= (1 << bitsLeft) - 1;
      }
    }
    if (output.isEmpty) throw const FormatException('动态验证码密钥过短');
    return Uint8List.fromList(output);
  }
}
