import '../../models/models.dart';

/// 未入架也可按书源查询；页面地址与章节归属主键分别传入。— Codex + Bridge
abstract interface class BookSourceQueryService {
  Future<Book> getBookInfo(
    BookSource source,
    String pageUrl, {
    Book? existingBook,
    bool canReName = true,
  });
  Future<List<BookChapter>> getChapters(
    BookSource source,
    String pageUrl, {
    required String bookUrl,
    String tocUrl = '',
    String bookName = '',
  });
}
