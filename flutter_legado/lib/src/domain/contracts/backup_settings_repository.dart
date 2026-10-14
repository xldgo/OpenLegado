import '../models/backup_settings.dart';

/// 备份路径和有效同步开关的同源访问，空路径删除原键。— Codex + UI
abstract interface class BackupSettingsRepository {
  BackupSettings get current;
  Stream<BackupSettings> watch();
  Future<BackupSettings> load();
  Future<void> reload();
  Future<void> update({String? backupPath, bool? syncBookProgress});
}
