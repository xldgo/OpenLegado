/// 备份与进度同步普通偏好，不含连接凭据和同步结果。— Codex + UI
final class BackupSettings {
  const BackupSettings({
    this.backupPath = '',
    this.syncBookProgress = true,
    this.autoSync = false,
    this.syncBookProgressPlus = false,
  });

  final String backupPath;
  final bool syncBookProgress;
  final bool autoSync;
  final bool syncBookProgressPlus;

  @override
  bool operator ==(Object other) =>
      other is BackupSettings &&
      backupPath == other.backupPath &&
      syncBookProgress == other.syncBookProgress &&
      autoSync == other.autoSync &&
      syncBookProgressPlus == other.syncBookProgressPlus;

  @override
  int get hashCode =>
      Object.hash(backupPath, syncBookProgress, autoSync, syncBookProgressPlus);
}
