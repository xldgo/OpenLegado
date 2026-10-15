/// 章节正文缓存的持久化访问，不管理下载任务或全局缓存。— Codex + Bridge
abstract interface class ChapterCacheRepository {
  Future<int> clearBookCache(String bookUrl);
  Future<int> clearChapterCache(String bookUrl, int chapterIndex);

  /// 未缓存时返回空串。
  Future<String> getCachedChapter(String bookUrl, int chapterIndex);
  Future<List<String>> listCachedChapterUrls(String bookUrl);

  /// 章节URL到字数的映射，空字数不收录。
  Future<Map<String, String>> listCachedChapters(String bookUrl);
}
