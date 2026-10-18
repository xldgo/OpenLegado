import '../bridge/rust_errors.dart';
import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/explore_state_repository.dart';

/// infoMap继续由Rust持有，不在Dart建立第二份权威状态。— Codex + Bridge
final class RustExploreStateRepository implements ExploreStateRepository {
  const RustExploreStateRepository();
  @override
  Future<void> put(String sourceUrl, String key, String value) => rustFuture(
    () =>
        bridge.exploreInfoMapPut(sourceUrl: sourceUrl, key: key, value: value),
    operation: 'exploreInfoMapPut',
  );
  @override
  Future<void> ensureDefault(
    String sourceUrl,
    String key,
    String defaultValue,
  ) => rustFuture(
    () => bridge.exploreInfoMapEnsureDefault(
      sourceUrl: sourceUrl,
      key: key,
      defaultValue: defaultValue,
    ),
    operation: 'exploreInfoMapEnsureDefault',
  );
  @override
  Future<Map<String, String>> snapshot(String sourceUrl) async {
    return rustFuture(
      () => bridge.exploreInfoMapSnapshot(sourceUrl: sourceUrl),
      operation: 'exploreInfoMapSnapshot',
    );
  }
}
