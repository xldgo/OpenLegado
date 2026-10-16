import '../../domain/contracts/chapter_cache_repository.dart';
import '../../domain/contracts/reading_repository.dart';

/// 阅读与朗读共用纯正文获取策略，不持有页面或播放会话。— Codex + Bridge
class ChapterContentService {
  const ChapterContentService({required this._reading, required this._cache});

  final ReadingRepository _reading;
  final ChapterCacheRepository _cache;

  Future<String> read(String bookUrl, int chapterIndex) =>
      _isLocalBookUrl(bookUrl)
      ? _reading.getChapterContent(bookUrl, chapterIndex)
      : _reading.getChapterContentFull(bookUrl, chapterIndex);

  /// 保持先失效当前章、再抓取的顺序；失败交由会话展示，不清其他章。
  Future<String> refresh({
    required String bookUrl,
    required int chapterIndex,
    required String chapterUrl,
    required String sourceUrl,
  }) async {
    await _cache.clearChapterCache(bookUrl, chapterIndex);
    return _reading.fetchChapterContent(bookUrl, chapterUrl, sourceUrl);
  }

  /// 镜像Rust的本地扩展名判定；本地普通入口负责还原相对文件路径。
  /// 在线普通入口返回章节地址元数据，因此在线正文必须走Full链路。
  static bool _isLocalBookUrl(String bookUrl) {
    final lower = bookUrl.toLowerCase();
    return const [
      '.epub',
      '.txt',
      '.text',
      '.mobi',
      '.azw',
      '.azw3',
      '.pdf',
      '.cbz',
    ].any(lower.endsWith);
  }
}
