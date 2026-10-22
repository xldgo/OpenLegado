import '../bridge/rust_errors.dart';
import '../../bridge/ffi/ffi.dart' as bridge;
import '../bridge/bookmark_dto_mapping.dart';
import '../../domain/contracts/bookmark_repository.dart';
import '../../models/misc.dart';

/// 直接调用已有 FRB；运行时与数据库由应用启动流程初始化。— Codex + Bridge
final class RustBookmarkRepository implements BookmarkRepository {
  const RustBookmarkRepository();

  @override
  Future<List<Bookmark>> getAllBookmarks() async => (await rustFuture(
    () => bridge.bookmarkList(),
    operation: 'bookmarkList',
  )).map(bookmarkFromDto).toList();

  @override
  Future<List<Bookmark>> getBookmarksByBook(
    String bookName,
    String bookAuthor,
  ) async => (await rustFuture(
    () => bridge.getBookmarksByBook(bookName: bookName, bookAuthor: bookAuthor),
    operation: 'getBookmarksByBook',
  )).map(bookmarkFromDto).toList();

  @override
  Future<Bookmark> addBookmark(Bookmark bookmark) async {
    final id = await rustFuture(
      () => bridge.bookmarkAdd(
        bookName: bookmark.bookName,
        bookAuthor: bookmark.bookAuthor,
        chapterIndex: bookmark.chapterIndex,
        chapterPos: bookmark.chapterPos,
        chapterName: bookmark.chapterName,
        bookText: bookmark.bookText,
        content: bookmark.content,
      ),
      operation: 'bookmarkAdd',
    );
    return bookmark.copyWith(id: id);
  }

  @override
  Future<void> updateBookmark(Bookmark bookmark) => rustFuture(
    () => bridge.bookmarkUpdate(bookmark: bookmarkToDto(bookmark)),
    operation: 'bookmarkUpdate',
  );

  @override
  Future<void> deleteBookmark(int id) => rustFuture(
    () => bridge.bookmarkDelete(bookmarkId: id),
    operation: 'bookmarkDelete',
  );

  @override
  Future<List<Bookmark>> searchBookmarks(String keyword) async =>
      (await rustFuture(
        () => bridge.bookmarkSearch(keyword: keyword),
        operation: 'bookmarkSearch',
      )).map(bookmarkFromDto).toList();
}
