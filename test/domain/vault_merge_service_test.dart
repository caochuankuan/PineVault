import 'package:flutter_test/flutter_test.dart';
import 'package:pine_vault/domain/models/vault.dart';
import 'package:pine_vault/domain/models/vault_item.dart';
import 'package:pine_vault/domain/use_cases/vault_merge_service.dart';

void main() {
  final mergeService = VaultMergeService();

  test('merges independent local and remote edits', () {
    final first = _item('first', title: 'First');
    final second = _item('second', title: 'Second');
    final base = _vault(items: [first, second]);
    final local = _vault(
      items: [
        first.copyWith(title: 'Local first', revision: 2),
        second,
      ],
    );
    final remote = _vault(
      items: [
        first,
        second.copyWith(title: 'Remote second', revision: 2),
      ],
    );

    final result = mergeService.merge(base: base, local: local, remote: remote);

    expect(result.conflictCount, 0);
    expect(
      result.vault.items.firstWhere((item) => item.id == 'first').title,
      'Local first',
    );
    expect(
      result.vault.items.firstWhere((item) => item.id == 'second').title,
      'Remote second',
    );
  });

  test('keeps both versions when the same item changes on both sides', () {
    final original = _item('same', title: 'Original');
    final result = mergeService.merge(
      base: _vault(items: [original]),
      local: _vault(items: [original.copyWith(title: 'Local', revision: 2)]),
      remote: _vault(
        items: [original.copyWith(password: 'remote-password', revision: 2)],
      ),
    );

    expect(result.conflictCount, 1);
    expect(result.vault.items, hasLength(2));
    expect(
      result.vault.items.any(
        (item) => item.id == 'same' && item.title == 'Local',
      ),
      isTrue,
    );
    expect(
      result.vault.items.any((item) => item.title.endsWith('（同步冲突）')),
      isTrue,
    );
    expect(
      result.vault.items.any((item) => item.password == 'remote-password'),
      isTrue,
    );
  });

  test('preserves deletion and edited content as a conflict copy', () {
    final original = _item('deleted', title: 'Original');
    final result = mergeService.merge(
      base: _vault(items: [original]),
      local: _vault(tombstones: const ['deleted']),
      remote: _vault(
        items: [original.copyWith(title: 'Remote edit', revision: 2)],
      ),
    );

    expect(result.conflictCount, 1);
    expect(result.vault.tombstones, contains('deleted'));
    expect(result.vault.items, hasLength(1));
    expect(result.vault.items.single.id, isNot('deleted'));
    expect(result.vault.items.single.title, 'Remote edit（同步冲突）');
  });

  test('unions items safely when no prior baseline exists', () {
    final result = mergeService.merge(
      base: null,
      local: _vault(items: [_item('local', title: 'Local')]),
      remote: _vault(items: [_item('remote', title: 'Remote')]),
    );

    expect(result.conflictCount, 0);
    expect(
      result.vault.items.map((item) => item.id),
      containsAll(['local', 'remote']),
    );
  });
}

Vault _vault({
  List<VaultItem> items = const [],
  List<String> tombstones = const [],
}) {
  final now = DateTime.utc(2026, 9, 7);
  return Vault(
    id: 'vault-id',
    schemaVersion: 1,
    createdAt: now,
    updatedAt: now,
    items: items,
    tombstones: tombstones,
  );
}

VaultItem _item(String id, {required String title}) {
  final now = DateTime.utc(2026, 9, 7);
  return VaultItem(
    id: id,
    type: VaultItemType.login,
    title: title,
    username: 'person@example.com',
    password: 'password',
    urls: const [],
    notes: '',
    favorite: false,
    createdAt: now,
    updatedAt: now,
    revision: 1,
  );
}
