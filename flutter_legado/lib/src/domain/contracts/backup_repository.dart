import '../models/old_data_import_result.dart';
import '../models/backup_restore_result.dart';

/// 本地业务数据备份访问，不持有界面或设置刷新状态。— Codex + Bridge
abstract interface class BackupRepository {
  Future<String> backup(
    String dirPath, {
    Map<String, dynamic> preferences = const {},
    Map<String, String> files = const {},
    Map<String, dynamic> sensitive = const {},
    String? password,
    String? fileName,
  });
  Future<BackupRestoreResult> restore(
    String backupPath, {
    String? password,
    Set<String> ignore = const {},
  });
  Future<List<String>> backupList(String dir);
  Future<OldDataImportResult> importOldData(String dirPath);
}
