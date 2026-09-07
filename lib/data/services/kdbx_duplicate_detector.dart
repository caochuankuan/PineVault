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

  int count({required Vault vault, required KdbxImportData data}) =>
      data.entries.length - withoutDuplicates(vault: vault, data: data).length;

  List<KdbxImportEntry> withoutDuplicates({
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
    return data.entries
        .where((entry) => signatures.add(_importEntrySignature(entry)))
        .toList(growable: false);
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
