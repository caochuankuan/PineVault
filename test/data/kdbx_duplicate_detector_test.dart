import 'package:flutter_test/flutter_test.dart';
import 'package:pine_vault/data/models/kdbx_transfer_data.dart';
import 'package:pine_vault/data/services/kdbx_duplicate_detector.dart';
import 'package:pine_vault/domain/models/vault.dart';
import 'package:pine_vault/domain/models/vault_group.dart';
import 'package:pine_vault/domain/models/vault_item.dart';

void main() {
  test('detects existing and repeated KDBX entries', () {
    final now = DateTime.utc(2026, 9, 7);
    final vault = Vault(
      id: 'vault',
      schemaVersion: 2,
      createdAt: now,
      updatedAt: now,
      groups: [
        VaultGroup(id: 'default', name: '未分组', createdAt: now, updatedAt: now),
      ],
      items: [
        VaultItem(
          id: 'existing',
          groupId: 'default',
          type: VaultItemType.login,
          title: 'Example',
          username: 'person@example.com',
          password: 'secret',
          urls: const ['https://example.com'],
          notes: '本机备注',
          favorite: false,
          createdAt: now,
          updatedAt: now,
          revision: 1,
        ),
      ],
      tombstones: const [],
    );
    final duplicate = KdbxImportEntry(
      groupName: '未分组',
      title: 'example',
      username: 'PERSON@example.com',
      password: 'secret',
      url: 'https://example.com',
      notes: '备注不同仍视为同一账号',
      favorite: true,
      createdAt: now,
      updatedAt: now,
    );
    final unique = KdbxImportEntry(
      groupName: '未分组',
      title: 'Another',
      username: 'other@example.com',
      password: 'another-secret',
      url: 'https://other.example.com',
      notes: '',
      favorite: false,
      createdAt: now,
      updatedAt: now,
    );
    final data = KdbxImportData(entries: [duplicate, unique, unique]);

    const detector = KdbxDuplicateDetector();
    expect(detector.count(vault: vault, data: data), 2);
    expect(detector.withoutDuplicates(vault: vault, data: data), [unique]);
  });
}
