/// 本地业务数据备份访问，不持有界面或设置刷新状态。— Codex + Bridge
abstract interface class BackupRepository {
  Future<String> backup(String dirPath);
  Future<void> restore(String backupPath);
  Future<List<String>> backupList(String dir);
  Future<String> importOldData(String dirPath);
}
