import '../models/backup_settings.dart';

/// 备份路径与同步策略同源读取；只写现有有效项，空路径删除原键。— Codex + UI
abstract interface class BackupSettingsRepository {
  BackupSettings get current;
  Stream<BackupSettings> watch();
  Future<BackupSettings> load();
  Future<void> reload();
  Future<void> update({
    String? backupPath,
    bool? syncBookProgress,
    bool? includeCloudCredentials,
    bool? onlyLatestBackup,
    bool? autoCheckNewBackup,
    bool? autoBackup,
    int? autoBackupIntervalDays,
    bool? autoBackupWebDav,
  });
}
