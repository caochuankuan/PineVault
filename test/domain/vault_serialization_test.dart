import 'package:flutter_test/flutter_test.dart';
import 'package:pine_vault/domain/models/vault.dart';
import 'package:pine_vault/domain/models/vault_item.dart';
import 'package:pine_vault/domain/models/totp_config.dart';
import 'package:pine_vault/domain/models/webdav_configuration.dart';

void main() {
  test('vault JSON round trip preserves values', () {
    final now = DateTime.utc(2026, 9, 7, 3);
    final original = Vault(
      id: 'vault-id',
      schemaVersion: 1,
      createdAt: now,
      updatedAt: now,
      items: [
        VaultItem(
          id: 'item-id',
          type: VaultItemType.login,
          title: 'Example',
          username: 'user@example.com',
          password: 'secret',
          urls: const ['https://example.com'],
          notes: 'note',
          totp: const TotpConfig(
            secret: 'JBSWY3DPEHPK3PXP',
            algorithm: TotpAlgorithm.sha256,
            digits: 8,
            period: 60,
            issuer: 'Example',
            account: 'user@example.com',
          ),
          favorite: true,
          createdAt: now,
          updatedAt: now,
          revision: 1,
        ),
      ],
      tombstones: const ['deleted-id'],
      webDavCredentials: WebDavCredentials(
        serverUri: Uri.parse('https://dav.example.test/dav/'),
        username: 'person@example.com',
        password: 'application-password',
      ),
    );

    final decoded = Vault.fromJson(original.toJson());
    expect(decoded.id, original.id);
    expect(decoded.items.single.password, 'secret');
    expect(decoded.items.single.urls, ['https://example.com']);
    expect(decoded.items.single.totp?.secret, 'JBSWY3DPEHPK3PXP');
    expect(decoded.items.single.totp?.algorithm, TotpAlgorithm.sha256);
    expect(decoded.items.single.totp?.digits, 8);
    expect(decoded.items.single.totp?.period, 60);
    expect(decoded.tombstones, ['deleted-id']);
    expect(decoded.webDavCredentials?.username, 'person@example.com');
    expect(decoded.webDavCredentials?.password, 'application-password');
  });

  test('vault JSON without WebDAV configuration remains readable', () {
    final decoded = Vault.fromJson({
      'id': 'existing-vault',
      'schemaVersion': 1,
      'createdAt': '2026-09-07T03:00:00.000Z',
      'updatedAt': '2026-09-07T03:00:00.000Z',
      'items': <dynamic>[],
      'tombstones': <dynamic>[],
    });

    expect(decoded.webDavCredentials, isNull);
    expect(decoded.schemaVersion, 4);
  });
}
