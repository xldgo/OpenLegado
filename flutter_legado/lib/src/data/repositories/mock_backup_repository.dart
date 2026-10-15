import 'dart:convert';

import '../../domain/contracts/backup_repository.dart';

/// 本地备份访问沿用原方法行为。— Codex + Bridge
final class MockBackupRepository implements BackupRepository {
  const MockBackupRepository();
  // ========== 备份操作 ==========

  @override
  Future<String> backup(String dirPath) async {
    return '$dirPath/legado_backup_mock.json';
  }

  @override
  Future<void> restore(String backupPath) async {}

  @override
  Future<List<String>> backupList(String dir) async => [];

  @override
  Future<String> importOldData(String dirPath) async {
    return jsonEncode({
      'books': 0,
      'bookSources': 0,
      'replaceRules': 0,
      'messages': <String>['mock: 未找到旧版备份文件'],
    });
  }
}
