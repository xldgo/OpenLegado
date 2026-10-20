import 'package:flutter_legado/src/domain/contracts/bookshelf_repository.dart';
import 'package:flutter_legado/src/models/book.dart';

/// 场景测试只覆盖单本读取或更新，其他操作仍用同一根 Mock 存储。— Codex + UI
final class TestBookshelfRepository implements BookshelfRepository {
  TestBookshelfRepository({
    required this._delegate,
    this._getBook,
    this._updateBook,
  });
  final BookshelfRepository _delegate;
  final Future<Book?> Function(String)? _getBook;
  final Future<void> Function(Book)? _updateBook;

  @override
  Future<Book?> getBook(String url) =>
      _getBook?.call(url) ?? _delegate.getBook(url);
  @override
  Future<void> updateBook(Book book) =>
      _updateBook?.call(book) ?? _delegate.updateBook(book);
  @override
  Future<List<Book>> getBooks() => _delegate.getBooks();
  @override
  Future<Book> addBook(Book book) => _delegate.addBook(book);
  @override
  Future<void> deleteBook(String url) => _delegate.deleteBook(url);
  @override
  Future<void> topBook(String url) => _delegate.topBook(url);
  @override
  Future<void> unTopBook(String url) => _delegate.unTopBook(url);
  @override
  Future<void> setBookGroup(String url, int groupId) =>
      _delegate.setBookGroup(url, groupId);
  @override
  Future<int> importBooks(String json) => _delegate.importBooks(json);
  @override
  Future<void> reorderBooks(List<Map<String, dynamic>> orders) =>
      _delegate.reorderBooks(orders);
}
