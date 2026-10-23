import '../../models/book_chapter.dart';
import '../../models/book.dart';

/// 目录、正文及进度访问，不持有阅读器或播放会话。— Codex + UI
abstract interface class ReadingRepository {
  /// 只读取得书级覆盖与全局默认共同决定的有效状态，不要求书籍已入库。
  Future<bool> resolveReplaceRule(Book book, bool defaultEnabled);

  Future<List<BookChapter>> getChapters(String bookUrl);
  Future<String> getChapterContent(String bookUrl, int chapterIndex);
  Future<String> getChapterContentRaw(String bookUrl, int chapterIndex);
  Future<String> getChapterContentFull(String bookUrl, int chapterIndex);
  Future<String> fetchChapterContent(
    String bookUrl,
    String chapterUrl,
    String sourceUrl,
  );
  Future<bool> saveChapterContent({
    required String bookUrl,
    required int chapterIndex,
    required String title,
    required String content,
  });

  /// 沿用既有位置语义；正文原文锚点与音视频毫秒由各自会话管理。
  Future<void> updateReadingProgress({
    required String bookUrl,
    required int chapterIndex,
    required int chapterPos,
  });
  Future<List<BookChapter>> refreshToc(String bookUrl, String sourceUrl);
}
