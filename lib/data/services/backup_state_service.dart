import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class BackupState {
  const BackupState({
    this.automaticEnabled = true,
    this.lastLocalAt,
    this.lastWebDavAt,
  });

  final bool automaticEnabled;
  final DateTime? lastLocalAt;
  final DateTime? lastWebDavAt;

  BackupState copyWith({
    bool? automaticEnabled,
    DateTime? lastLocalAt,
    DateTime? lastWebDavAt,
  }) => BackupState(
    automaticEnabled: automaticEnabled ?? this.automaticEnabled,
    lastLocalAt: lastLocalAt ?? this.lastLocalAt,
    lastWebDavAt: lastWebDavAt ?? this.lastWebDavAt,
  );
}

class BackupStateService {
  BackupStateService({Future<Directory> Function()? directoryProvider})
    : _directoryProvider = directoryProvider ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directoryProvider;

  Future<BackupState> read(String vaultId) async {
    final file = await _file(vaultId);
    if (!await file.exists()) return const BackupState();
    try {
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return BackupState(
        automaticEnabled: json['automaticEnabled'] as bool? ?? true,
        lastLocalAt: _date(json['lastLocalAt']),
        lastWebDavAt: _date(json['lastWebDavAt']),
      );
    } on FormatException {
      return const BackupState();
    } on TypeError {
      return const BackupState();
    }
  }

  Future<void> write(String vaultId, BackupState state) async {
    final file = await _file(vaultId);
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      jsonEncode({
        'automaticEnabled': state.automaticEnabled,
        'lastLocalAt': state.lastLocalAt?.toIso8601String(),
        'lastWebDavAt': state.lastWebDavAt?.toIso8601String(),
      }),
      flush: true,
    );
    await temporary.rename(file.path);
  }

  DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toUtc() : null;

  Future<File> _file(String vaultId) async {
    final support = await _directoryProvider();
    return File('${support.path}/PineVault/backup-state-$vaultId.json');
  }
}
