/// 备份与进度同步普通偏好，不含连接凭据和同步结果。— Codex + UI
final class BackupSettings {
  const BackupSettings({this.backupPath = '', this.syncBookProgress = true});

  final String backupPath;
  final bool syncBookProgress;

  @override
  bool operator ==(Object other) =>
      other is BackupSettings &&
      backupPath == other.backupPath &&
      syncBookProgress == other.syncBookProgress;

  @override
  int get hashCode => Object.hash(backupPath, syncBookProgress);
}
