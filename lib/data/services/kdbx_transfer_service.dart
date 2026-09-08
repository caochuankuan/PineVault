import 'dart:typed_data';

import 'package:kpasslib/kpasslib.dart';

import '../../domain/models/vault.dart';
import '../../domain/models/vault_item.dart';
import '../../domain/models/totp_config.dart';
import '../models/kdbx_transfer_data.dart';
import 'totp_service.dart';

typedef _ImportedTotp = ({TotpConfig? config, String? error});

class KdbxTransferService {
  static const _favoriteTag = 'PineVault:Favorite';
  static const _totpField = 'otp';
  static const _totpSecretField = 'TimeOtp-Secret-Base32';
  static const _totpPeriodField = 'TimeOtp-Period';
  static const _totpLengthField = 'TimeOtp-Length';
  static const _totpAlgorithmField = 'TimeOtp-Algorithm';

  const KdbxTransferService({TotpService totpService = const TotpService()})
    : _totpService = totpService;

  final TotpService _totpService;

  Future<KdbxImportData> decode({
    required Uint8List bytes,
    required String password,
  }) async {
    final credentials = KdbxCredentials(
      password: ProtectedData.fromString(password),
    );
    try {
      final database = await KdbxDatabase.fromBytes(
        data: bytes,
        credentials: credentials,
      );
      final entries = <KdbxImportEntry>[];
      _readEntries(database.root.entries, '未分组', entries);
      for (final group in database.root.groups) {
        if (group.uuid == database.meta.recycleBinUuid) continue;
        _readGroup(group, '', entries);
      }
      return KdbxImportData(entries: List.unmodifiable(entries));
    } on InvalidCredentialsError {
      throw const FormatException('KDBX 主密码错误，或该文件还需要密钥文件');
    } on FileCorruptedError {
      throw const FormatException('KDBX 文件损坏或格式不受支持');
    } on UnsupportedValueError {
      throw const FormatException('暂不支持该 KDBX 文件的版本或加密方式');
    }
  }

  Future<Uint8List> encode({
    required Vault vault,
    required String password,
  }) async {
    final credentials = KdbxCredentials(
      password: ProtectedData.fromString(password),
    );
    final database = KdbxDatabase.create(credentials: credentials, name: '松匣');
    for (final group in vault.groups) {
      final kdbxGroup = database.createGroup(
        parent: database.root,
        name: group.name,
      );
      for (final item in vault.items.where(
        (item) => item.groupId == group.id,
      )) {
        _writeEntry(database, kdbxGroup, item);
      }
    }

    final knownGroupIds = vault.groups.map((group) => group.id).toSet();
    for (final item in vault.items.where(
      (item) => !knownGroupIds.contains(item.groupId),
    )) {
      _writeEntry(database, database.root, item);
    }
    return Uint8List.fromList(await database.save());
  }

  void _readGroup(
    KdbxGroup group,
    String parentPath,
    List<KdbxImportEntry> output,
  ) {
    final groupName = group.name.trim().isEmpty ? '未分组' : group.name.trim();
    final path = parentPath.isEmpty ? groupName : '$parentPath / $groupName';
    _readEntries(group.entries, path, output);
    for (final child in group.groups) {
      _readGroup(child, path, output);
    }
  }

  void _readEntries(
    Iterable<KdbxEntry> entries,
    String groupName,
    List<KdbxImportEntry> output,
  ) {
    final now = DateTime.now().toUtc();
    for (final entry in entries) {
      final createdAt = entry.times.creation.time?.toUtc() ?? now;
      final updatedAt = entry.times.modification.time?.toUtc() ?? createdAt;
      final importedTotp = _readTotp(entry);
      output.add(
        KdbxImportEntry(
          groupName: groupName,
          title: _field(entry, 'Title'),
          username: _field(entry, 'UserName'),
          password: _field(entry, 'Password'),
          url: _field(entry, 'URL'),
          notes: _field(entry, 'Notes'),
          tags: List.unmodifiable(
            (entry.tags ?? const []).where((tag) => tag != _favoriteTag),
          ),
          totp: importedTotp.config,
          totpError: importedTotp.error,
          favorite:
              entry.icon == KdbxIcon.star ||
              (entry.tags?.contains(_favoriteTag) ?? false),
          createdAt: createdAt,
          updatedAt: updatedAt,
        ),
      );
    }
  }

  String _field(KdbxEntry entry, String name) => entry.fields[name]?.text ?? '';

  _ImportedTotp _readTotp(KdbxEntry entry) {
    final otp = _field(entry, _totpField).trim();
    final nativeSecret = _field(entry, _totpSecretField).trim();
    if (otp.isEmpty && nativeSecret.isEmpty) return (config: null, error: null);
    try {
      if (otp.isNotEmpty) return (config: _totpService.parse(otp), error: null);
      final base = _totpService.parse(nativeSecret);
      final digitsText = _field(entry, _totpLengthField).trim();
      final periodText = _field(entry, _totpPeriodField).trim();
      final digits = digitsText.isEmpty ? 6 : int.tryParse(digitsText);
      final period = periodText.isEmpty ? 30 : int.tryParse(periodText);
      if (digits != 6 && digits != 8) {
        throw const FormatException('动态验证码位数只支持 6 或 8');
      }
      if (period == null || period <= 0) {
        throw const FormatException('动态验证码周期无效');
      }
      final algorithm = _nativeAlgorithm(_field(entry, _totpAlgorithmField));
      return (
        config: base.copyWith(
          algorithm: algorithm,
          digits: digits,
          period: period,
          issuer: _field(entry, 'Title').trim(),
          account: _field(entry, 'UserName').trim(),
        ),
        error: null,
      );
    } on FormatException catch (error) {
      return (config: null, error: error.message.toString());
    }
  }

  TotpAlgorithm _nativeAlgorithm(String value) {
    return switch (value.trim().toUpperCase().replaceAll('-', '')) {
      '' || 'SHA1' || 'HMACSHA1' => TotpAlgorithm.sha1,
      'SHA256' || 'HMACSHA256' => TotpAlgorithm.sha256,
      'SHA512' || 'HMACSHA512' => TotpAlgorithm.sha512,
      _ => throw const FormatException('不支持该动态验证码算法'),
    };
  }

  void _writeEntry(KdbxDatabase database, KdbxGroup group, VaultItem item) {
    final entry = database.createEntry(parent: group);
    entry.fields.addAll({
      'Title': KdbxTextField.fromText(text: item.title),
      'UserName': KdbxTextField.fromText(text: item.username),
      'Password': KdbxTextField.fromText(text: item.password, protected: true),
      'URL': KdbxTextField.fromText(
        text: item.urls.isEmpty ? '' : item.urls.first,
      ),
      'Notes': KdbxTextField.fromText(text: item.notes),
      if (item.totp case final totp?) ...{
        _totpField: KdbxTextField.fromText(
          text: _totpService.toUri(totp).toString(),
          protected: true,
        ),
        _totpSecretField: KdbxTextField.fromText(
          text: _totpService.normalizeSecret(totp.secret),
          protected: true,
        ),
        _totpPeriodField: KdbxTextField.fromText(text: totp.period.toString()),
        _totpLengthField: KdbxTextField.fromText(text: totp.digits.toString()),
        _totpAlgorithmField: KdbxTextField.fromText(
          text: switch (totp.algorithm) {
            TotpAlgorithm.sha1 => 'HMAC-SHA-1',
            TotpAlgorithm.sha256 => 'HMAC-SHA-256',
            TotpAlgorithm.sha512 => 'HMAC-SHA-512',
          },
        ),
      },
    });
    entry.icon = item.favorite ? KdbxIcon.star : KdbxIcon.key;
    entry.tags = [...item.tags, if (item.favorite) _favoriteTag];
    entry.times = KdbxTimes.fromTime(item.createdAt.toUtc());
    entry.times.modification = KdbxTime(item.updatedAt.toUtc());
  }
}
