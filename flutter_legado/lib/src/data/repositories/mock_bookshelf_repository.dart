import 'dart:convert';

import '../../domain/contracts/bookshelf_repository.dart';
import '../../models/book.dart';

/// Mock 跨域共用的唯一书籍存储；UI 只接触 Repository。— Codex + Bridge
final class MockBookshelfStore {
  MockBookshelfStore({this._load});
  final Future<void> Function()? _load;
  final List<Book> books = [];
  Future<void>? _loading;

  Future<void> ensureLoaded() =>
      _loading ??= _load?.call() ?? Future<void>.value();
}

/// 复用原 Mock 书架语义，不建立第二份章节或进度状态。
final class MockBookshelfRepository implements BookshelfRepository {
  MockBookshelfRepository({MockBookshelfStore? store})
    : _store = store ?? MockBookshelfStore();
  final MockBookshelfStore _store;

  // ========== 书架操作 ==========

  @override
  Future<List<Book>> getBooks() async {
    await _store.ensureLoaded();
    return List.from(_store.books);
  }

  @override
  Future<Book> addBook(Book book) async {
    await _store.ensureLoaded();
    _store.books.add(book);
    return book;
  }

  @override
  Future<void> updateBook(Book book) async {
    await _store.ensureLoaded();
    final idx = _store.books.indexWhere((b) => b.bookUrl == book.bookUrl);
    if (idx >= 0) _store.books[idx] = book;
  }

  @override
  Future<Book> setCanUpdate(String bookUrl, bool canUpdate) async {
    await _store.ensureLoaded();
    final index = _store.books.indexWhere((book) => book.bookUrl == bookUrl);
    if (index < 0) throw StateError('书籍不存在');
    final book = _store.books[index];
    final updated = book.copyWith(
      canUpdate: canUpdate,
      bookType: canUpdate
          ? book.bookType
          : book.bookType & ~BookType.updateError,
    );
    _store.books[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteBook(String bookUrl) async {
    await _store.ensureLoaded();
    _store.books.removeWhere((b) => b.bookUrl == bookUrl);
  }

  @override
  Future<Book?> getBook(String bookUrl) async {
    await _store.ensureLoaded();
    try {
      return _store.books.firstWhere((b) => b.bookUrl == bookUrl);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> topBook(String bookUrl) async {
    await _store.ensureLoaded();
    final idx = _store.books.indexWhere((b) => b.bookUrl == bookUrl);
    if (idx >= 0) _store.books[idx] = _store.books[idx].copyWith(order: -1);
  }

  @override
  Future<void> unTopBook(String bookUrl) async {
    await _store.ensureLoaded();
    final idx = _store.books.indexWhere((b) => b.bookUrl == bookUrl);
    if (idx >= 0) _store.books[idx] = _store.books[idx].copyWith(order: 0);
  }

  @override
  Future<void> setBookGroup(String bookUrl, int groupId) async {
    await _store.ensureLoaded();
    final idx = _store.books.indexWhere((b) => b.bookUrl == bookUrl);
    if (idx >= 0) {
      _store.books[idx] = _store.books[idx].copyWith(group: groupId);
    }
  }

  @override
  Future<int> importBooks(String jsonArray) async {
    final list = jsonDecode(jsonArray) as List<dynamic>;
    return list.length;
  }

  @override
  Future<void> reorderBooks(List<Map<String, dynamic>> orders) async {
    await _store.ensureLoaded();
    for (final item in orders) {
      final url = item['bookUrl'] as String?;
      final order = item['order'] as int?;
      if (url == null || order == null) continue;
      final idx = _store.books.indexWhere((b) => b.bookUrl == url);
      if (idx >= 0) {
        _store.books[idx] = _store.books[idx].copyWith(order: order);
      }
    }
    _store.books.sort((a, b) => a.order.compareTo(b.order));
  }
}
