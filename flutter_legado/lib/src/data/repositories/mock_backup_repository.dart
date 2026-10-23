import '../../domain/models/old_data_import_result.dart';
import '../../domain/models/backup_restore_stats.dart';
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
  Future<BackupRestoreStats> restore(String backupPath) async =>
      const BackupRestoreStats(
        books: 0,
        bookmarks: 0,
        replaceRules: 0,
        bookSources: 0,
        rssSources: 0,
        readRecords: 0,
      );

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
