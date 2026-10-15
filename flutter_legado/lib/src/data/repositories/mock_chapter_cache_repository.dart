import '../../domain/contracts/chapter_cache_repository.dart';

/// 保留现有Mock的缓存占位行为，不冒充真实下载或数据库。— Codex + Bridge
class MockChapterCacheRepository implements ChapterCacheRepository {
  const MockChapterCacheRepository();

  @override
  Future<int> clearBookCache(String bookUrl) async => 0;
  @override
  Future<int> clearChapterCache(String bookUrl, int chapterIndex) async => 0;
  @override
  Future<String> getCachedChapter(String bookUrl, int chapterIndex) async =>
      '（mock 缓存正文：$bookUrl 第 $chapterIndex 章）';
  @override
  Future<List<String>> listCachedChapterUrls(String bookUrl) async => const [];
  @override
  Future<Map<String, String>> listCachedChapters(String bookUrl) async =>
      const {};
}
