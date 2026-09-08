import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../models/vault.dart';
import '../models/vault_item.dart';
import '../models/vault_group.dart';

class VaultMergeResult {
  const VaultMergeResult({
    required this.vault,
    required this.conflictCount,
    required this.webDavConflict,
  });

  final Vault vault;
  final int conflictCount;
  final bool webDavConflict;
}

class VaultMergeService {
  VaultMergeService({Uuid uuid = const Uuid()}) : _uuid = uuid;

  final Uuid _uuid;

  VaultMergeResult merge({
    Vault? base,
    required Vault local,
    required Vault remote,
  }) {
    if (local.id != remote.id || (base != null && base.id != local.id)) {
      throw const FormatException('同步文件不属于当前密码库');
    }
    final ids = <String>{
      ...local.items.map((item) => item.id),
      ...remote.items.map((item) => item.id),
      ...local.tombstones,
      ...remote.tombstones,
      if (base != null) ...base.items.map((item) => item.id),
      if (base != null) ...base.tombstones,
    };
    final items = <VaultItem>[];
    final tombstones = <String>{};
    var conflicts = 0;

    for (final id in ids) {
      final baseEntry = base == null ? null : _entry(base, id);
      final localEntry = _entry(local, id);
      final remoteEntry = _entry(remote, id);
      if (base == null &&
          (localEntry.kind == _EntryKind.absent ||
              remoteEntry.kind == _EntryKind.absent)) {
        _addEntry(
          localEntry.kind == _EntryKind.absent ? remoteEntry : localEntry,
          items,
          tombstones,
        );
        continue;
      }
      if (_same(localEntry, remoteEntry)) {
        _addEntry(localEntry, items, tombstones);
      } else if (baseEntry != null && _same(localEntry, baseEntry)) {
        _addEntry(remoteEntry, items, tombstones);
      } else if (baseEntry != null && _same(remoteEntry, baseEntry)) {
        _addEntry(localEntry, items, tombstones);
      } else {
        conflicts++;
        _addConflict(id, localEntry, remoteEntry, items, tombstones);
      }
    }

    final groups = _mergeGroups(local, remote);
    final groupIds = groups.map((group) => group.id).toSet();
    final normalizedItems = [
      for (final item in items)
        groupIds.contains(item.groupId)
            ? item
            : item.copyWith(
                groupId: 'default',
                updatedAt: DateTime.now().toUtc(),
                revision: item.revision + 1,
              ),
    ];
    normalizedItems.sort((a, b) => a.id.compareTo(b.id));
    final sortedTombstones = tombstones.toList()..sort();
    final groupTombstones = {
      ...local.groupTombstones,
      ...remote.groupTombstones,
    }.toList()..sort();
    return VaultMergeResult(
      vault: Vault(
        id: local.id,
        schemaVersion: local.schemaVersion,
        createdAt: local.createdAt,
        updatedAt: DateTime.now().toUtc(),
        items: List.unmodifiable(normalizedItems),
        tombstones: List.unmodifiable(sortedTombstones),
        groups: List.unmodifiable(groups),
        groupTombstones: List.unmodifiable(groupTombstones),
        groupOrderUpdatedAt: _groupOrderUpdatedAt(local, remote),
        webDavCredentials: local.webDavCredentials ?? remote.webDavCredentials,
      ),
      conflictCount: conflicts,
      webDavConflict:
          local.webDavCredentials != null &&
          remote.webDavCredentials != null &&
          !_sameWebDav(local, remote),
    );
  }

  bool _sameWebDav(Vault left, Vault right) {
    final leftCredentials = left.webDavCredentials;
    final rightCredentials = right.webDavCredentials;
    if (leftCredentials == null || rightCredentials == null) {
      return leftCredentials == rightCredentials;
    }
    return leftCredentials.serverUri == rightCredentials.serverUri &&
        leftCredentials.username == rightCredentials.username &&
        leftCredentials.password == rightCredentials.password;
  }

  List<VaultGroup> _mergeGroups(Vault local, Vault remote) {
    final byId = <String, VaultGroup>{
      for (final group in local.groups) group.id: group,
    };
    for (final group in remote.groups) {
      final previous = byId[group.id];
      if (previous == null || group.updatedAt.isAfter(previous.updatedAt)) {
        byId[group.id] = group;
      }
    }
    final deleted = {...local.groupTombstones, ...remote.groupTombstones};
    final preferredOrder =
        _groupOrderUpdatedAt(local, remote) == remote.groupOrderUpdatedAt
        ? remote.groups
        : local.groups;
    final result = <VaultGroup>[];
    for (final group in preferredOrder) {
      final merged = byId[group.id];
      if (merged != null && !deleted.contains(merged.id)) result.add(merged);
    }
    final present = result.map((group) => group.id).toSet();
    final remaining =
        byId.values
            .where(
              (group) =>
                  !deleted.contains(group.id) && !present.contains(group.id),
            )
            .toList()
          ..sort((a, b) {
            final created = a.createdAt.compareTo(b.createdAt);
            return created != 0 ? created : a.id.compareTo(b.id);
          });
    result.addAll(remaining);
    final defaultGroups = result.where((group) => group.id == 'default');
    final otherGroups = result.where((group) => group.id != 'default');
    return [...defaultGroups, ...otherGroups];
  }

  DateTime? _groupOrderUpdatedAt(Vault local, Vault remote) {
    final localTime = local.groupOrderUpdatedAt;
    final remoteTime = remote.groupOrderUpdatedAt;
    if (localTime == null) return remoteTime;
    if (remoteTime == null) return localTime;
    return remoteTime.isAfter(localTime) ? remoteTime : localTime;
  }

  void _addConflict(
    String id,
    _Entry local,
    _Entry remote,
    List<VaultItem> items,
    Set<String> tombstones,
  ) {
    final localItem = local.item;
    final remoteItem = remote.item;
    if (localItem != null && remoteItem != null) {
      items.add(localItem);
      items.add(_conflictCopy(remoteItem));
      return;
    }
    if (local.kind == _EntryKind.deleted || remote.kind == _EntryKind.deleted) {
      tombstones.add(id);
      final preserved = localItem ?? remoteItem;
      if (preserved != null) items.add(_conflictCopy(preserved));
      return;
    }
    _addEntry(localItem != null ? local : remote, items, tombstones);
  }

  VaultItem _conflictCopy(VaultItem item) {
    final now = DateTime.now().toUtc();
    return VaultItem(
      id: _uuid.v4(),
      groupId: item.groupId,
      type: item.type,
      title: '${item.title}（同步冲突）',
      username: item.username,
      password: item.password,
      urls: item.urls,
      notes: item.notes,
      favorite: item.favorite,
      createdAt: now,
      updatedAt: now,
      revision: 1,
    );
  }

  _Entry _entry(Vault vault, String id) {
    if (vault.tombstones.contains(id)) return _Entry.deleted(id);
    for (final item in vault.items) {
      if (item.id == id) return _Entry.item(item);
    }
    return _Entry.absent(id);
  }

  bool _same(_Entry left, _Entry right) {
    if (left.kind != right.kind) return false;
    if (left.item == null) return true;
    return jsonEncode(left.item!.toJson()) == jsonEncode(right.item!.toJson());
  }

  void _addEntry(_Entry entry, List<VaultItem> items, Set<String> tombstones) {
    if (entry.item case final item?) items.add(item);
    if (entry.kind == _EntryKind.deleted) {
      tombstones.add(entry.id);
    }
  }
}

enum _EntryKind { absent, item, deleted }

class _Entry {
  const _Entry.absent(this.id) : kind = _EntryKind.absent, item = null;
  const _Entry.deleted(this.id) : kind = _EntryKind.deleted, item = null;
  _Entry.item(VaultItem this.item) : id = item.id, kind = _EntryKind.item;

  final String id;
  final _EntryKind kind;
  final VaultItem? item;
}
