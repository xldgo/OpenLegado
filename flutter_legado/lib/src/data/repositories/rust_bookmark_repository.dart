import '../../bridge/ffi/ffi.dart' as bridge;
import '../../bridge/transfer_dto.dart' as dto;
import '../../domain/contracts/bookmark_repository.dart';
import '../../models/misc.dart';

/// 直接调用已有 FRB；运行时与数据库由应用启动流程初始化。— Codex + Bridge
final class RustBookmarkRepository implements BookmarkRepository {
  const RustBookmarkRepository();

  Bookmark _fromDto(dto.BookmarkDto value) => Bookmark(
    id: value.id,
    time: value.time,
    bookName: value.bookName,
    bookAuthor: value.bookAuthor,
    chapterIndex: value.chapterIndex,
    chapterPos: value.chapterPos,
    chapterName: value.chapterName,
    bookText: value.bookText,
    content: value.content,
  );

  dto.BookmarkDto _toDto(Bookmark value) => dto.BookmarkDto(
    id: value.id,
    time: value.time,
    bookName: value.bookName,
    bookAuthor: value.bookAuthor,
    chapterIndex: value.chapterIndex,
    chapterPos: value.chapterPos,
    chapterName: value.chapterName,
    bookText: value.bookText,
    content: value.content,
  );

  @override
  Future<List<Bookmark>> getAllBookmarks() async =>
      (await bridge.bookmarkList()).map(_fromDto).toList();

  @override
  Future<List<Bookmark>> getBookmarksByBook(
    String bookName,
    String bookAuthor,
  ) async => (await bridge.getBookmarksByBook(
    bookName: bookName,
    bookAuthor: bookAuthor,
  )).map(_fromDto).toList();

  @override
  Future<Bookmark> addBookmark(Bookmark bookmark) async {
    final id = await bridge.bookmarkAdd(
      bookName: bookmark.bookName,
      bookAuthor: bookmark.bookAuthor,
      chapterIndex: bookmark.chapterIndex,
      chapterPos: bookmark.chapterPos,
      chapterName: bookmark.chapterName,
      bookText: bookmark.bookText,
      content: bookmark.content,
    );
    return bookmark.copyWith(id: id);
  }

  @override
  Future<void> updateBookmark(Bookmark bookmark) =>
      bridge.bookmarkUpdate(bookmark: _toDto(bookmark));

  @override
  Future<void> deleteBookmark(int id) => bridge.bookmarkDelete(bookmarkId: id);

  @override
  Future<List<Bookmark>> searchBookmarks(String keyword) async =>
      (await bridge.bookmarkSearch(keyword: keyword)).map(_fromDto).toList();
}
