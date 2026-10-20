import '../../models/book.dart';

/// 书架数据访问，不拥有阅读器状态或重算阅读位置。— Codex + UI
abstract interface class BookshelfRepository {
  Future<List<Book>> getBooks();
  Future<Book> addBook(Book book);
  Future<void> updateBook(Book book);
  Future<void> deleteBook(String bookUrl);
  Future<Book?> getBook(String bookUrl);
  Future<void> topBook(String bookUrl);
  Future<void> unTopBook(String bookUrl);
  Future<void> setBookGroup(String bookUrl, int groupId);
  Future<int> importBooks(String jsonArray);
  Future<void> reorderBooks(List<Map<String, dynamic>> orders);
}
