/// 备份与进度同步普通偏好，不含连接凭据和同步结果。— Codex + UI
final class BackupSettings {
  const BackupSettings({
    this.backupPath = '',
    this.includeCloudCredentials = false,
    this.onlyLatestBackup = true,
    this.autoCheckNewBackup = true,
    this.autoBackup = false,
    this.autoBackupIntervalDays = 1,
    this.autoBackupWebDav = false,
    this.syncBookProgress = true,
    this.autoSync = false,
    this.syncBookProgressPlus = false,
  });

  final String backupPath;
  final bool includeCloudCredentials;
  final bool onlyLatestBackup, autoCheckNewBackup, autoBackup, autoBackupWebDav;
  final int autoBackupIntervalDays;
  final bool syncBookProgress;
  final bool autoSync;
  final bool syncBookProgressPlus;

  @override
  bool operator ==(Object other) =>
      other is BackupSettings &&
      backupPath == other.backupPath &&
      includeCloudCredentials == other.includeCloudCredentials &&
      onlyLatestBackup == other.onlyLatestBackup &&
      autoCheckNewBackup == other.autoCheckNewBackup &&
      autoBackup == other.autoBackup &&
      autoBackupIntervalDays == other.autoBackupIntervalDays &&
      autoBackupWebDav == other.autoBackupWebDav &&
      syncBookProgress == other.syncBookProgress &&
      autoSync == other.autoSync &&
      syncBookProgressPlus == other.syncBookProgressPlus;

  @override
  int get hashCode => Object.hash(
    onlyLatestBackup,
    autoCheckNewBackup,
    autoBackup,
    autoBackupIntervalDays,
    autoBackupWebDav,
    includeCloudCredentials,
    backupPath,
    syncBookProgress,
    autoSync,
    syncBookProgressPlus,
  );
}
