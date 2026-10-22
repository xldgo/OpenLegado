import '../../domain/contracts/book_source_query_service.dart';
import '../../models/models.dart';

/// 沿用Mock详情和空目录，不模拟网络或落库。— Codex + Bridge
final class MockBookSourceQueryService implements BookSourceQueryService {
  const MockBookSourceQueryService();
  @override
  Future<Book> getBookInfo(
    BookSource source,
    String pageUrl, {
    Book? existingBook,
    bool canReName = true,
  }) async => Book(
    bookUrl: pageUrl,
    origin: source.bookSourceUrl,
    originName: source.bookSourceName,
    name: 'Mock书籍',
    author: 'Mock作者',
  );
  @override
  Future<List<BookChapter>> getChapters(
    BookSource source,
    String pageUrl, {
    required String bookUrl,
    String tocUrl = '',
    String bookName = '',
  }) async => const [];
}
