/// 自动任务执行结果，不代表所有底层业务动作均已实现。— Codex + Bridge
final class AutoTaskExecutionResult {
  const AutoTaskExecutionResult({
    required this.success,
    this.taskId = '',
    this.message = '',
    this.durationMs = 0,
    this.details,
  });
  final String taskId;
  final bool success;
  final String message;
  final int durationMs;
  final String? details;
}
