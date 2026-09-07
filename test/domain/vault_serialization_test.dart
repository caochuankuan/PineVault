import 'package:flutter_test/flutter_test.dart';
import 'package:pine_vault/domain/models/vault.dart';
import 'package:pine_vault/domain/models/vault_item.dart';
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
  });
}
