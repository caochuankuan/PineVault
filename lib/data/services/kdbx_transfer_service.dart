import 'dart:typed_data';

import 'package:kpasslib/kpasslib.dart';

import '../../domain/models/vault.dart';
import '../../domain/models/vault_item.dart';
import '../models/kdbx_transfer_data.dart';

class KdbxTransferService {
  static const _favoriteTag = 'PineVault:Favorite';

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
    });
    entry.icon = item.favorite ? KdbxIcon.star : KdbxIcon.key;
    entry.tags = [...item.tags, if (item.favorite) _favoriteTag];
    entry.times = KdbxTimes.fromTime(item.createdAt.toUtc());
    entry.times.modification = KdbxTime(item.updatedAt.toUtc());
  }
}
