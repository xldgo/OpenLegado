/// 本地包已生成后的云端、清理及记录结果；失败不会隐去可用文件。
final class BackupCreationResult {
  const BackupCreationResult({
    required this.path,
    this.completed = true,
    this.warnings = const [],
  });
  final String path;
  final bool completed;
  final List<String> warnings;
}
