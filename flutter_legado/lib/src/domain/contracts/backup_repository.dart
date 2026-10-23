import '../models/old_data_import_result.dart';
import '../models/backup_restore_stats.dart';

/// 本地业务数据备份访问，不持有界面或设置刷新状态。— Codex + Bridge
abstract interface class BackupRepository {
  Future<String> backup(String dirPath);
  Future<BackupRestoreStats> restore(String backupPath);
  Future<List<String>> backupList(String dir);
  Future<OldDataImportResult> importOldData(String dirPath);
}
