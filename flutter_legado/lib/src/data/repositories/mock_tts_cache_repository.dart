import '../../domain/contracts/tts_cache_repository.dart';

/// Mock 不创建原生音频文件；缓存页如实显示空目录。— Codex + Bridge
final class MockTtsCacheRepository implements TtsCacheRepository {
  @override
  bool get supportsAudioFiles => false;
  const MockTtsCacheRepository();
  @override
  Future<void> record(String path, TtsCacheContext context) async {}
  @override
  Future<List<TtsCacheEntry>> list() async => const [];
  @override
  Future<TtsCacheClearResult> clear({
    String? name,
    int? beforeTimestampMs,
    String? keepBookUrl,
    int? keepChapterIndex,
  }) async => const TtsCacheClearResult();
}
