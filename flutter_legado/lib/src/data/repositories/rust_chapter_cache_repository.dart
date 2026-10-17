import '../../bridge/rust_lib.dart' as bridge;
import '../../domain/contracts/chapter_cache_repository.dart';

/// 复用既有FRB章节缓存入口，错误响应不得冒充空缓存。— Codex + Bridge
class RustChapterCacheRepository implements ChapterCacheRepository {
  const RustChapterCacheRepository();

  @override
  Future<int> clearBookCache(String bookUrl) =>
      bridge.cacheClearBook(bookUrl: bookUrl);

  @override
  Future<int> clearChapterCache(String bookUrl, int chapterIndex) =>
      bridge.cacheClearChapter(bookUrl: bookUrl, chapterIndex: chapterIndex);

  @override
  Future<String> getCachedChapter(String bookUrl, int chapterIndex) =>
      bridge.cacheGetChapter(bookUrl: bookUrl, chapterIndex: chapterIndex);

  @override
  Future<List<String>> listCachedChapterUrls(String bookUrl) async {
    return List.unmodifiable(
      await bridge.cacheListCachedChapterUrls(bookUrl: bookUrl),
    );
  }

  @override
  Future<Map<String, String>> listCachedChapters(String bookUrl) async {
    final entries = await bridge.cacheListCachedChapters(bookUrl: bookUrl);
    return Map.unmodifiable({
      for (final v in entries)
        if (v.url.isNotEmpty && v.wordCount.isNotEmpty) v.url: v.wordCount,
    });
  }
}
