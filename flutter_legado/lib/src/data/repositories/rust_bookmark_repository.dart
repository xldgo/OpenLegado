import 'dart:convert';

import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/bookmark_repository.dart';
import '../../models/misc.dart';
import '../bridge/rust_json_decode.dart';

/// 直接调用已有 FRB；运行时与数据库由应用启动流程初始化。— Codex + Bridge
final class RustBookmarkRepository implements BookmarkRepository {
  const RustBookmarkRepository();

  List<Bookmark> _decode(String json) => decodeRustJsonList(
    json,
    'bookApi',
  ).map((item) => Bookmark.fromJson(item as Map<String, dynamic>)).toList();

  @override
  Future<List<Bookmark>> getAllBookmarks() async =>
      _decode(await bridge.bookmarkList());

  @override
  Future<List<Bookmark>> getBookmarksByBook(
    String bookName,
    String bookAuthor,
  ) async => _decode(
    await bridge.getBookmarksByBook(bookName: bookName, bookAuthor: bookAuthor),
  );

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
      bridge.bookmarkUpdate(bookmarkJson: jsonEncode(bookmark.toJson()));

  @override
  Future<void> deleteBookmark(int id) => bridge.bookmarkDelete(bookmarkId: id);

  @override
  Future<List<Bookmark>> searchBookmarks(String keyword) async =>
      _decode(await bridge.bookmarkSearch(keyword: keyword));
}
