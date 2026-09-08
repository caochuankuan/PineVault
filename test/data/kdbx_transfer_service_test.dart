import 'package:flutter_test/flutter_test.dart';
import 'package:pine_vault/data/services/kdbx_transfer_service.dart';
import 'package:pine_vault/domain/models/vault.dart';
import 'package:pine_vault/domain/models/vault_group.dart';
import 'package:pine_vault/domain/models/vault_item.dart';
import 'package:pine_vault/domain/models/totp_config.dart';

void main() {
  final createdAt = DateTime.utc(2026, 9, 7, 8);
  final updatedAt = DateTime.utc(2026, 9, 7, 9);
  final vault = Vault(
    id: 'vault-id',
    schemaVersion: 2,
    createdAt: createdAt,
    updatedAt: updatedAt,
    groups: [
      VaultGroup(
        id: 'work',
        name: '工作',
        createdAt: createdAt,
        updatedAt: updatedAt,
      ),
    ],
    items: [
      VaultItem(
        id: 'entry-id',
        groupId: 'work',
        type: VaultItemType.login,
        title: '示例网站',
        username: 'user@example.com',
        password: 'secret-value',
        urls: const ['https://example.com'],
        notes: '测试备注',
        totp: const TotpConfig(
          secret: 'JBSWY3DPEHPK3PXP',
          algorithm: TotpAlgorithm.sha256,
          digits: 8,
          period: 60,
          issuer: '示例网站',
          account: 'user@example.com',
        ),
        favorite: true,
        createdAt: createdAt,
        updatedAt: updatedAt,
        revision: 1,
      ),
    ],
    tombstones: const [],
  );

  test('exports and imports a password-protected KDBX database', () async {
    final service = KdbxTransferService();
    final bytes = await service.encode(vault: vault, password: '12345678');
    final imported = await service.decode(bytes: bytes, password: '12345678');

    expect(bytes, isNotEmpty);
    expect(imported.entries, hasLength(1));
    final entry = imported.entries.single;
    expect(entry.groupName, '工作');
    expect(entry.title, '示例网站');
    expect(entry.username, 'user@example.com');
    expect(entry.password, 'secret-value');
    expect(entry.url, 'https://example.com');
    expect(entry.notes, '测试备注');
    expect(entry.totp?.secret, 'JBSWY3DPEHPK3PXP');
    expect(entry.totp?.algorithm, TotpAlgorithm.sha256);
    expect(entry.totp?.digits, 8);
    expect(entry.totp?.period, 60);
    expect(entry.totp?.issuer, '示例网站');
    expect(entry.totp?.account, 'user@example.com');
    expect(entry.totpError, isNull);
    expect(entry.favorite, isTrue);
    expect(entry.createdAt, createdAt);
    expect(entry.updatedAt, updatedAt);
  });

  test('rejects an incorrect KDBX password', () async {
    final service = KdbxTransferService();
    final bytes = await service.encode(vault: vault, password: '12345678');

    expect(
      () => service.decode(bytes: bytes, password: 'wrong-password'),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('主密码错误'),
        ),
      ),
    );
  });
}
