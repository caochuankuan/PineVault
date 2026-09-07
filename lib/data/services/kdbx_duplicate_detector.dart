import '../../domain/models/vault.dart';
import '../../domain/models/vault_item.dart';
import '../models/kdbx_transfer_data.dart';

typedef _DuplicateSignature = ({
  String group,
  String title,
  String username,
  String password,
  String url,
});

class KdbxDuplicateDetector {
  const KdbxDuplicateDetector();

  Set<int> duplicateIndexes({
    required Vault vault,
    required KdbxImportData data,
  }) {
    final groupNamesById = <String, String>{
      for (final group in vault.groups) group.id: group.name,
    };
    final signatures = <_DuplicateSignature>{
      for (final item in vault.items)
        _vaultItemSignature(item, groupNamesById[item.groupId] ?? '未分组'),
    };
    final duplicates = <int>{};
    for (var index = 0; index < data.entries.length; index++) {
      if (!signatures.add(_importEntrySignature(data.entries[index]))) {
        duplicates.add(index);
      }
    }
    return Set.unmodifiable(duplicates);
  }

  int count({required Vault vault, required KdbxImportData data}) =>
      duplicateIndexes(vault: vault, data: data).length;

  List<KdbxImportEntry> withoutDuplicates({
    required Vault vault,
    required KdbxImportData data,
  }) {
    final duplicates = duplicateIndexes(vault: vault, data: data);
    return [
      for (var index = 0; index < data.entries.length; index++)
        if (!duplicates.contains(index)) data.entries[index],
    ];
  }

  _DuplicateSignature _vaultItemSignature(VaultItem item, String groupName) => (
    group: groupName.trim().toLowerCase(),
    title: item.title.trim().toLowerCase(),
    username: item.username.trim().toLowerCase(),
    password: item.password,
    url: (item.urls.isEmpty ? '' : item.urls.first).trim().toLowerCase(),
  );

  _DuplicateSignature _importEntrySignature(KdbxImportEntry entry) => (
    group: entry.groupName.trim().toLowerCase(),
    title: entry.title.trim().toLowerCase(),
    username: entry.username.trim().toLowerCase(),
    password: entry.password,
    url: entry.url.trim().toLowerCase(),
  );
}
