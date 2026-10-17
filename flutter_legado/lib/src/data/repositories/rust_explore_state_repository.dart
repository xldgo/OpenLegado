import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/explore_state_repository.dart';

/// infoMap继续由Rust持有，不在Dart建立第二份权威状态。— Codex + Bridge
final class RustExploreStateRepository implements ExploreStateRepository {
  const RustExploreStateRepository();
  @override
  Future<void> put(String sourceUrl, String key, String value) =>
      bridge.exploreInfoMapPut(sourceUrl: sourceUrl, key: key, value: value);
  @override
  Future<void> ensureDefault(
    String sourceUrl,
    String key,
    String defaultValue,
  ) => bridge.exploreInfoMapEnsureDefault(
    sourceUrl: sourceUrl,
    key: key,
    defaultValue: defaultValue,
  );
  @override
  Future<Map<String, String>> snapshot(String sourceUrl) async {
    return bridge.exploreInfoMapSnapshot(sourceUrl: sourceUrl);
  }
}
