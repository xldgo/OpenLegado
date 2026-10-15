import '../../domain/contracts/cache_repository.dart';

/// 保留旧Mock固定统计及清理空操作，仅供界面开发。— Codex + Bridge
final class MockCacheRepository implements CacheRepository {
  const MockCacheRepository();

  @override
  Future<int> getCacheSize() async => 50 * 1024 * 1024;

  @override
  Future<int> getCacheBookCount() async => 3;

  @override
  Future<int> getCacheChapterCount() async => 30;

  @override
  Future<void> clearCache() async {}

  @override
  Future<void> clearCacheBefore(int beforeTimestampMs) async {}
}
