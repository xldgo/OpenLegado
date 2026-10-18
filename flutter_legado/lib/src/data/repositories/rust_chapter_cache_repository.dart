import '../bridge/rust_errors.dart';
import '../../bridge/rust_lib.dart' as bridge;
import '../../domain/contracts/chapter_cache_repository.dart';

/// 复用既有FRB章节缓存入口，错误响应不得冒充空缓存。— Codex + Bridge
class RustChapterCacheRepository implements ChapterCacheRepository {
  const RustChapterCacheRepository();

  @override
  Future<int> clearBookCache(String bookUrl) => rustFuture(
    () => bridge.cacheClearBook(bookUrl: bookUrl),
    operation: 'cacheClearBook',
  );

  @override
  Future<int> clearChapterCache(String bookUrl, int chapterIndex) => rustFuture(
    () =>
        bridge.cacheClearChapter(bookUrl: bookUrl, chapterIndex: chapterIndex),
    operation: 'cacheClearChapter',
  );

  @override
  Future<String> getCachedChapter(String bookUrl, int chapterIndex) =>
      rustFuture(
        () => bridge.cacheGetChapter(
          bookUrl: bookUrl,
          chapterIndex: chapterIndex,
        ),
        operation: 'cacheGetChapter',
      );

  @override
  Future<List<String>> listCachedChapterUrls(String bookUrl) async {
    return List.unmodifiable(
      await rustFuture(
        () => bridge.cacheListCachedChapterUrls(bookUrl: bookUrl),
        operation: 'cacheListCachedChapterUrls',
      ),
    );
  }

  @override
  Future<Map<String, String>> listCachedChapters(String bookUrl) async {
    final entries = await rustFuture(
      () => bridge.cacheListCachedChapters(bookUrl: bookUrl),
      operation: 'cacheListCachedChapters',
    );
    return Map.unmodifiable({
      for (final v in entries)
        if (v.url.isNotEmpty && v.wordCount.isNotEmpty) v.url: v.wordCount,
    });
  }
}
