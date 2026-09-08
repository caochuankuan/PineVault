import 'dart:typed_data';

import 'package:sodium_libs/sodium_libs_sumo.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/vault.dart';
import '../../domain/models/vault_item.dart';
import '../../domain/models/vault_group.dart';
import '../../domain/models/webdav_configuration.dart';
import '../models/kdbx_transfer_data.dart';
import '../models/vault_envelope.dart';
import '../serialization/vault_codec.dart';
import '../services/crypto_service.dart';
import '../services/kdbx_duplicate_detector.dart';
import '../services/vault_file_service.dart';

class VaultRepository {
  VaultRepository({
    required SodiumCryptoService cryptoService,
    required VaultFileService fileService,
    required VaultCodec codec,
    Uuid uuid = const Uuid(),
  }) : _cryptoService = cryptoService,
       _fileService = fileService,
       _codec = codec,
       _uuid = uuid;

  final SodiumCryptoService _cryptoService;
  final VaultFileService _fileService;
  final VaultCodec _codec;
  final Uuid _uuid;

  Vault? _vault;
  VaultEnvelope? _envelope;
  SecureKey? _key;

  Vault? get vault => _vault;
  String? get currentVaultId => _envelope?.vaultId;

  Future<String> storedVaultId() async {
    return _codec.decodeEnvelope(await _fileService.read()).vaultId;
  }

  VaultEnvelope decodeEnvelope(String encoded) =>
      _codec.decodeEnvelope(encoded);

  String exportEncryptedVault() {
    final envelope = _envelope;
    if (envelope == null) throw StateError('Vault is locked.');
    return _codec.encodeEnvelope(envelope);
  }

  String encryptVaultForExport(Vault vault) {
    final current = _requireVault();
    final envelope = _envelope;
    final key = _key;
    if (envelope == null || key == null) throw StateError('Vault is locked.');
    if (vault.id != current.id) {
      throw const FormatException('不能导出其他密码库');
    }
    final encrypted = _cryptoService.encryptVault(
      envelope: envelope,
      key: key,
      vault: vault,
    );
    return _codec.encodeEnvelope(encrypted);
  }

  Vault decryptEncryptedVault(String encoded) {
    final current = _requireVault();
    final key = _key;
    if (key == null) throw StateError('Vault is locked.');
    final envelope = _codec.decodeEnvelope(encoded);
    if (envelope.vaultId != current.id) {
      throw const FormatException('同步文件不属于当前密码库');
    }
    return _cryptoService.decryptVault(envelope: envelope, key: key);
  }

  Future<void> replaceVault(Vault vault) async {
    final current = _requireVault();
    if (vault.id != current.id) {
      throw const FormatException('不能替换为其他密码库');
    }
    await _save(vault);
  }

  Future<bool> hasVault() => _fileService.exists();

  String validateRestore(String masterPassword, String encoded) {
    final envelope = _codec.decodeEnvelope(encoded);
    final unlocked = _cryptoService.unlock(
      masterPassword: masterPassword,
      envelope: envelope,
    );
    try {
      return unlocked.vault.id;
    } finally {
      unlocked.key.dispose();
    }
  }

  Future<void> restore(String masterPassword, String encoded) async {
    if (await hasVault()) throw StateError('本机已经存在密码库');
    final envelope = _codec.decodeEnvelope(encoded);
    final unlocked = _cryptoService.unlock(
      masterPassword: masterPassword,
      envelope: envelope,
    );
    try {
      await _fileService.write(encoded);
    } catch (_) {
      unlocked.key.dispose();
      rethrow;
    }
    _replaceSession(
      vault: unlocked.vault,
      envelope: unlocked.envelope,
      key: unlocked.key,
    );
  }

  Future<void> create(String masterPassword) async {
    final now = DateTime.now().toUtc();
    final vault = Vault(
      id: _uuid.v4(),
      schemaVersion: 1,
      createdAt: now,
      updatedAt: now,
      items: const [],
      groups: [
        VaultGroup(id: 'default', name: '未分组', createdAt: now, updatedAt: now),
      ],
      tombstones: const [],
    );
    final created = _cryptoService.createVault(
      masterPassword: masterPassword,
      vault: vault,
    );
    try {
      await _fileService.write(_codec.encodeEnvelope(created.envelope));
    } catch (_) {
      created.key.dispose();
      rethrow;
    }
    _replaceSession(vault: vault, envelope: created.envelope, key: created.key);
  }

  Future<void> unlock(String masterPassword) async {
    final envelope = _codec.decodeEnvelope(await _fileService.read());
    final unlocked = _cryptoService.unlock(
      masterPassword: masterPassword,
      envelope: envelope,
    );
    _replaceSession(
      vault: unlocked.vault,
      envelope: unlocked.envelope,
      key: unlocked.key,
    );
  }

  Future<void> unlockWithDeviceKey(Uint8List rawVaultKey) async {
    final envelope = _codec.decodeEnvelope(await _fileService.read());
    final unlocked = _cryptoService.unlockWithVaultKey(
      rawVaultKey: rawVaultKey,
      envelope: envelope,
    );
    _replaceSession(
      vault: unlocked.vault,
      envelope: unlocked.envelope,
      key: unlocked.key,
    );
  }

  Uint8List exportDeviceUnlockKey(String masterPassword) {
    final envelope = _envelope;
    final key = _key;
    if (envelope == null || key == null) {
      throw StateError('密码库尚未解锁');
    }
    final verified = _cryptoService.unlock(
      masterPassword: masterPassword,
      envelope: envelope,
    );
    verified.key.dispose();
    return key.extractBytes();
  }

  Future<void> upsert({
    VaultItem? existing,
    String groupId = 'default',
    required String title,
    required String username,
    required String password,
    required String url,
    required String notes,
    List<String> tags = const [],
    required bool favorite,
  }) async {
    final vault = _requireVault();
    final now = DateTime.now().toUtc();
    final item = existing == null
        ? VaultItem(
            id: _uuid.v4(),
            groupId: groupId,
            type: VaultItemType.login,
            title: title.trim(),
            username: username.trim(),
            password: password,
            urls: url.trim().isEmpty ? const [] : [url.trim()],
            notes: notes,
            tags: tags,
            favorite: favorite,
            createdAt: now,
            updatedAt: now,
            revision: 1,
          )
        : existing.copyWith(
            groupId: groupId,
            title: title.trim(),
            username: username.trim(),
            password: password,
            urls: url.trim().isEmpty ? const [] : [url.trim()],
            notes: notes,
            tags: tags,
            favorite: favorite,
            updatedAt: now,
            revision: existing.revision + 1,
          );

    final items = [...vault.items];
    final index = items.indexWhere((candidate) => candidate.id == item.id);
    if (index == -1) {
      items.add(item);
    } else {
      items[index] = item;
    }
    await _save(vault.copyWith(updatedAt: now, items: items));
  }

  Future<void> createGroup(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw const FormatException('分组名称不能为空');
    final vault = _requireVault();
    if (vault.groups.any((group) => group.name == trimmed)) {
      throw const FormatException('分组名称已存在');
    }
    final now = DateTime.now().toUtc();
    final group = VaultGroup(
      id: _uuid.v4(),
      name: trimmed,
      createdAt: now,
      updatedAt: now,
    );
    await _save(
      vault.copyWith(updatedAt: now, groups: [...vault.groups, group]),
    );
  }

  int countKdbxDuplicates(KdbxImportData data) {
    final vault = _requireVault();
    return const KdbxDuplicateDetector().count(vault: vault, data: data);
  }

  Set<int> findKdbxDuplicateIndexes(KdbxImportData data) {
    final vault = _requireVault();
    return const KdbxDuplicateDetector().duplicateIndexes(
      vault: vault,
      data: data,
    );
  }

  Future<KdbxImportSummary> importKdbx(
    KdbxImportData data, {
    required bool skipDuplicates,
  }) async {
    final vault = _requireVault();
    final now = DateTime.now().toUtc();
    final groups = [...vault.groups];
    final groupIdsByName = <String, String>{
      for (final group in groups) group.name: group.id,
    };
    var createdGroupCount = 0;
    final items = [...vault.items];
    final entriesToImport = skipDuplicates
        ? const KdbxDuplicateDetector().withoutDuplicates(
            vault: vault,
            data: data,
          )
        : data.entries;
    final skippedDuplicateCount = data.entries.length - entriesToImport.length;

    for (final imported in entriesToImport) {
      var groupId = groupIdsByName[imported.groupName];
      if (groupId == null) {
        groupId = _uuid.v4();
        groups.add(
          VaultGroup(
            id: groupId,
            name: imported.groupName,
            createdAt: now,
            updatedAt: now,
          ),
        );
        groupIdsByName[imported.groupName] = groupId;
        createdGroupCount++;
      }
      items.add(
        VaultItem(
          id: _uuid.v4(),
          groupId: groupId,
          type: VaultItemType.login,
          title: imported.title,
          username: imported.username,
          password: imported.password,
          urls: imported.url.trim().isEmpty ? const [] : [imported.url.trim()],
          notes: imported.notes,
          tags: imported.tags,
          favorite: imported.favorite,
          createdAt: imported.createdAt,
          updatedAt: imported.updatedAt,
          revision: 1,
        ),
      );
    }

    final importedCount = entriesToImport.length;
    if (importedCount > 0) {
      await _save(vault.copyWith(updatedAt: now, groups: groups, items: items));
    }
    return KdbxImportSummary(
      itemCount: importedCount,
      createdGroupCount: createdGroupCount,
      skippedDuplicateCount: skippedDuplicateCount,
    );
  }

  Future<void> delete(VaultItem item) async {
    final vault = _requireVault();
    final items = vault.items
        .where((candidate) => candidate.id != item.id)
        .toList(growable: false);
    final tombstones = {...vault.tombstones, item.id}.toList(growable: false);
    await _save(
      vault.copyWith(
        updatedAt: DateTime.now().toUtc(),
        items: items,
        tombstones: tombstones,
      ),
    );
  }

  Future<void> deleteItems(Iterable<String> ids) async {
    final selected = ids.toSet();
    if (selected.isEmpty) return;
    final vault = _requireVault();
    final now = DateTime.now().toUtc();
    final items = vault.items.where((item) => !selected.contains(item.id));
    await _save(
      vault.copyWith(
        updatedAt: now,
        items: items.toList(growable: false),
        tombstones: {...vault.tombstones, ...selected}.toList(growable: false),
      ),
    );
  }

  Future<void> updateItems(
    Iterable<String> ids, {
    bool? favorite,
    String? groupId,
  }) async {
    final selected = ids.toSet();
    if (selected.isEmpty) return;
    final vault = _requireVault();
    final now = DateTime.now().toUtc();
    final items = [
      for (final item in vault.items)
        selected.contains(item.id)
            ? item.copyWith(
                favorite: favorite,
                groupId: groupId,
                updatedAt: now,
                revision: item.revision + 1,
              )
            : item,
    ];
    await _save(vault.copyWith(updatedAt: now, items: items));
  }

  Future<void> saveWebDavCredentials(WebDavCredentials credentials) async {
    final vault = _requireVault();
    await _save(
      vault.copyWith(
        updatedAt: DateTime.now().toUtc(),
        webDavCredentials: credentials,
      ),
    );
  }

  Future<void> clearWebDavCredentials() async {
    final vault = _requireVault();
    await _save(
      vault.copyWith(
        updatedAt: DateTime.now().toUtc(),
        clearWebDavCredentials: true,
      ),
    );
  }

  Future<void> changeMasterPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (newPassword.length < 8) {
      throw const FormatException('新主密码至少需要 8 个字符');
    }
    final envelope = _envelope;
    final key = _key;
    if (envelope == null || key == null) {
      throw StateError('密码库尚未解锁');
    }
    final updatedEnvelope = _cryptoService.changeMasterPassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
      envelope: envelope,
      vaultKey: key,
    );
    await _fileService.write(_codec.encodeEnvelope(updatedEnvelope));
    _envelope = updatedEnvelope;
  }

  Future<void> adoptKeyWrapping(String encoded) async {
    final current = _envelope;
    if (current == null || _key == null) {
      throw StateError('密码库尚未解锁');
    }
    final remote = _codec.decodeEnvelope(encoded);
    if (remote.vaultId != current.vaultId) {
      throw const FormatException('同步文件不属于当前密码库');
    }
    final updated = current.copyWithWrapping(
      newKdf: remote.kdf,
      newWrappedKey: remote.wrappedKey,
    );
    await _fileService.write(_codec.encodeEnvelope(updated));
    _envelope = updated;
  }

  void lock() {
    _key?.dispose();
    _key = null;
    _vault = null;
    _envelope = null;
  }

  Future<void> _save(Vault vault) async {
    final key = _key;
    final envelope = _envelope;
    if (key == null || envelope == null) {
      throw StateError('Vault is locked.');
    }
    final updatedEnvelope = _cryptoService.encryptVault(
      envelope: envelope,
      key: key,
      vault: vault,
    );
    final encoded = _codec.encodeEnvelope(updatedEnvelope);
    _codec.decodeEnvelope(encoded);
    await _fileService.write(encoded);
    _vault = vault;
    _envelope = updatedEnvelope;
  }

  Vault _requireVault() {
    final vault = _vault;
    if (vault == null) throw StateError('Vault is locked.');
    return vault;
  }

  void _replaceSession({
    required Vault vault,
    required VaultEnvelope envelope,
    required SecureKey key,
  }) {
    _key?.dispose();
    _vault = vault;
    _envelope = envelope;
    _key = key;
  }
}
