/// 应用领域异常：消息不包含桥接类型，原异常与堆栈供诊断保留。— Codex + Bridge
final class AppException implements Exception {
  const AppException(
    this.message, {
    this.operation,
    this.cause,
    this.sourceStackTrace,
  });

  final String message;
  final String? operation;
  final Object? cause;
  final StackTrace? sourceStackTrace;

  @override
  String toString() => message;
}
