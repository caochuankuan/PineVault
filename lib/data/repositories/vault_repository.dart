import 'package:sodium_libs/sodium_libs_sumo.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/vault.dart';
import '../../domain/models/vault_item.dart';
import '../models/vault_envelope.dart';
import '../serialization/vault_codec.dart';
import '../services/crypto_service.dart';
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

  Future<bool> hasVault() => _fileService.exists();

  Future<void> create(String masterPassword) async {
    final now = DateTime.now().toUtc();
    final vault = Vault(
      id: _uuid.v4(),
      schemaVersion: 1,
      createdAt: now,
      updatedAt: now,
      items: const [],
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

  Future<void> upsert({
    VaultItem? existing,
    required String title,
    required String username,
    required String password,
    required String url,
    required String notes,
    required bool favorite,
  }) async {
    final vault = _requireVault();
    final now = DateTime.now().toUtc();
    final item = existing == null
        ? VaultItem(
            id: _uuid.v4(),
            type: VaultItemType.login,
            title: title.trim(),
            username: username.trim(),
            password: password,
            urls: url.trim().isEmpty ? const [] : [url.trim()],
            notes: notes,
            favorite: favorite,
            createdAt: now,
            updatedAt: now,
            revision: 1,
          )
        : existing.copyWith(
            title: title.trim(),
            username: username.trim(),
            password: password,
            urls: url.trim().isEmpty ? const [] : [url.trim()],
            notes: notes,
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
