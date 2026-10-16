/// JS源语法检查结果，行号与消息由现有引擎提供。— Codex + Bridge
class SourceSyntaxResult {
  const SourceSyntaxResult({
    required this.valid,
    required this.message,
    this.line,
  });
  final bool valid;
  final String message;
  final int? line;
}
