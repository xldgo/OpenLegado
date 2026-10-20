/// 检查结果只表达既有Rust响应，不代表已导入规则。— Codex + Bridge
final class RuleSubCheckResult {
  const RuleSubCheckResult({
    required this.id,
    required this.url,
    required this.name,
    required this.dueForUpdate,
    required this.hasUpdate,
    this.remoteVersion,
    this.error,
  });

  final int id;
  final String url;
  final String name;
  final bool dueForUpdate;
  final bool hasUpdate;
  final String? remoteVersion;
  final String? error;
}

/// 应用结果保留合并统计与错误信息，不另存运行时状态。— Codex + Bridge
final class RuleSubApplyResult {
  const RuleSubApplyResult({
    required this.id,
    required this.url,
    required this.success,
    required this.itemsAdded,
    required this.itemsUpdated,
    required this.itemsRemoved,
    required this.totalItems,
    this.error,
  });

  final int id;
  final String url;
  final bool success;
  final int itemsAdded;
  final int itemsUpdated;
  final int itemsRemoved;
  final int totalItems;
  final String? error;
}
