import '../../domain/models/old_data_import_result.dart';
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
  Future<OldDataImportResult> importOldData(String dirPath) async {
    return const OldDataImportResult(
      books: 0,
      bookSources: 0,
      replaceRules: 0,
      messages: ['mock: 未找到旧版备份文件'],
    );
  }
}
