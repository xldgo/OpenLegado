/// 音频文件缓存查询与清理，保留既有辅助缓存降级。— Codex + Bridge
abstract interface class AudioCacheRepository {
  Future<bool> audioCacheQuery({
    required String bookUrl,
    required int chapterIndex,
    required String chapterUrl,
    required String chapterTitle,
  });
  Future<List<int>> audioCacheList({required String bookUrl});
  Future<int> audioCacheClearChapter({
    required String bookUrl,
    required int chapterIndex,
    required String chapterUrl,
    required String chapterTitle,
  });
  Future<int> audioCacheClearBook({required String bookUrl});
}
