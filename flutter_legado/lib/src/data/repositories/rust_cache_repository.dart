import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/cache_repository.dart';

/// 复用现有Rust缓存语义，不扩展到媒体和字体文件。— Codex + Bridge
final class RustCacheRepository implements CacheRepository {
  const RustCacheRepository();

  @override
  Future<int> getCacheSize() async => (await bridge.cacheGetSize()).toInt();

  @override
  Future<int> getCacheBookCount() => bridge.cacheGetBookCount();

  @override
  Future<int> getCacheChapterCount() => bridge.cacheGetChapterCount();

  @override
  Future<void> clearCache() async {
    if (!await bridge.cacheClear()) {
      throw StateError('全局缓存清理未成功');
    }
  }

  @override
  Future<void> clearCacheBefore(int beforeTimestampMs) async {
    if (!await bridge.cacheClearBefore(beforeTimestampMs: beforeTimestampMs)) {
      throw StateError('按时间清理缓存未成功');
    }
  }
}
