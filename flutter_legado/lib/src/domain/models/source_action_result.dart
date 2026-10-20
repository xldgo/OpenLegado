/// 购买结果不依赖传输JSON或UI路由。— Codex + Bridge
enum ChapterPurchaseKind { url, success, none }

class ChapterPurchaseResult {
  const ChapterPurchaseResult({required this.kind, required this.value});
  final ChapterPurchaseKind kind;
  final String value;
}

/// actions保留诊断信息；平台动作已由服务回放，消费者不得重复执行。
class SourceCallbackResult {
  SourceCallbackResult({
    required this.invoked,
    required this.jsTrue,
    this.raw = '',
    List<dynamic> actions = const [],
  }) : actions = List.unmodifiable(actions);
  final bool invoked;
  final bool jsTrue;
  final String raw;
  final List<dynamic> actions;
  bool get handled => invoked && jsTrue;
}
