import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pine_vault/data/models/sync_history_entry.dart';
import 'package:pine_vault/data/services/sync_history_service.dart';

void main() {
  test('persists newest sync history entry first', () async {
    final root = await Directory.systemTemp.createTemp('pine_history_test_');
    addTearDown(() => root.delete(recursive: true));
    final service = SyncHistoryService(directoryProvider: () async => root);

    await service.append(
      'vault-id',
      SyncHistoryEntry(
        timestamp: DateTime.utc(2026, 9, 7, 1),
        trigger: '手动同步',
        success: true,
        message: '密码库已上传',
      ),
    );
    await service.append(
      'vault-id',
      SyncHistoryEntry(
        timestamp: DateTime.utc(2026, 9, 7, 2),
        trigger: '定时自动同步',
        success: false,
        message: '连接超时',
      ),
    );

    final restored = await service.read('vault-id');
    expect(restored, hasLength(2));
    expect(restored.first.trigger, '定时自动同步');
    expect(restored.last.message, '密码库已上传');
  });
}
