/// 脚本结果与待回放的平台动作；动作协议由既有平台桥接解释。— Codex + Bridge
final class ExploreActionResult {
  ExploreActionResult({
    this.raw = '',
    List<dynamic> actions = const [],
    this.refreshExplore = false,
  }) : actions = List.unmodifiable(actions);
  final String raw;
  final List<dynamic> actions;
  final bool refreshExplore;
}
