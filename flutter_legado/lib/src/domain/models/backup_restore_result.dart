import 'backup_restore_stats.dart';

/// 已提交的业务结果和待应用的平台数据；不把跨存储写入冒充同一事务。
final class BackupRestoreResult {
  const BackupRestoreResult({
    required this.stats,
    this.preferences = const {},
    this.sensitive = const {},
    this.warnings = const [],
  });
  final BackupRestoreStats stats;
  final Map<String, dynamic> preferences;
  final Map<String, dynamic> sensitive;
  final List<String> warnings;
}

typedef BackupRestoreOutcome = ({
  BackupRestoreStats stats,
  Object? preferencesError,
  List<String> warnings,
});
