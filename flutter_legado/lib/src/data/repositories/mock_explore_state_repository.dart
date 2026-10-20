import '../../domain/contracts/explore_state_repository.dart';

/// 按书源隔离的同一Mock状态。— Codex + Bridge
final class MockExploreStateRepository implements ExploreStateRepository {
  final Map<String, Map<String, String>> _values = {};
  @override
  Future<void> put(String sourceUrl, String key, String value) async {
    _values.putIfAbsent(sourceUrl, () => {})[key] = value;
  }

  @override
  Future<void> ensureDefault(
    String sourceUrl,
    String key,
    String defaultValue,
  ) async {
    _values
        .putIfAbsent(sourceUrl, () => {})
        .putIfAbsent(key, () => defaultValue);
  }

  @override
  Future<Map<String, String>> snapshot(String sourceUrl) async =>
      Map.of(_values[sourceUrl] ?? const {});
}
