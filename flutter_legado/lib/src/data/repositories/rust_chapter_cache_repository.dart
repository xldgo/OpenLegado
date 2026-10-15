import '../../bridge/rust_lib.dart' as bridge;
import '../../domain/contracts/chapter_cache_repository.dart';
import '../bridge/rust_json_decode.dart';

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
    final items = decodeRustJsonList(
      await bridge.cacheListCachedChapterUrls(bookUrl: bookUrl),
      'listCachedChapterUrls',
    );
    return List.unmodifiable(
      items.map((item) {
        if (item is! String) {
          throw const FormatException('listCachedChapterUrls：章节URL必须是字符串');
        }
        return item;
      }),
    );
  }

  @override
  Future<Map<String, String>> listCachedChapters(String bookUrl) async {
    final items = decodeRustJsonList(
      await bridge.cacheListCachedChapters(bookUrl: bookUrl),
      'listCachedChapters',
    );
    final chapters = <String, String>{};
    for (final item in items) {
      if (item case {
        'url': final String url,
        'wordCount': final String count,
      }) {
        if (url.isNotEmpty && count.isNotEmpty) chapters[url] = count;
      } else {
        throw const FormatException(
          'listCachedChapters：条目必须包含字符串url和wordCount',
        );
      }
    }
    return Map.unmodifiable(chapters);
  }
}
