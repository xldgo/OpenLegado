import '../../domain/contracts/bookmark_repository.dart';
import '../../models/misc.dart';

/// 会话内书签的唯一存储；应用装配时复用原 Mock ID 分配器。— Codex + UI
class MockBookmarkRepository implements BookmarkRepository {
  MockBookmarkRepository({int Function()? nextId}) : _allocateId = nextId;

  final int Function()? _allocateId;
  int _nextId = 1;
  final List<Bookmark> _bookmarks = [];

  @override
  Future<List<Bookmark>> getAllBookmarks() async => List.of(_bookmarks);

  @override
  Future<List<Bookmark>> getBookmarksByBook(
    String bookName,
    String bookAuthor,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return _bookmarks
        .where((b) => b.bookName == bookName && b.bookAuthor == bookAuthor)
        .toList();
  }

  @override
  Future<Bookmark> addBookmark(Bookmark bookmark) async {
    final added = bookmark.copyWith(id: _allocateId?.call() ?? _nextId++);
    _bookmarks.add(added);
    return added;
  }

  @override
  Future<void> updateBookmark(Bookmark bookmark) async {
    final index = _bookmarks.indexWhere((b) => b.id == bookmark.id);
    if (index < 0) throw StateError('书签不存在: ${bookmark.id}');
    _bookmarks[index] = bookmark.copyWith(time: _bookmarks[index].time);
  }

  @override
  Future<void> deleteBookmark(int id) async {
    _bookmarks.removeWhere((b) => b.id == id);
  }

  @override
  Future<List<Bookmark>> searchBookmarks(String keyword) async => _bookmarks
      .where((b) => b.content.contains(keyword) || b.bookText.contains(keyword))
      .toList();
}
