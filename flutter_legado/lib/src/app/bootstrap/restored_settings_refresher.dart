/// 恢复后按既有顺序刷新，单项失败不阻断其余配置。— Codex + UI
class RestoredSettingsRefresher {
  RestoredSettingsRefresher(List<(String, Future<void> Function())> actions)
    : _actions = List.unmodifiable(actions);
  final List<(String, Future<void> Function())> _actions;

  Future<List<String>> refresh() async {
    final failures = <String>[];
    for (final (name, action) in _actions) {
      try {
        await action();
      } catch (_) {
        failures.add(name);
      }
    }
    return List.unmodifiable(failures);
  }
}
