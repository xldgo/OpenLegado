import '../../models/misc.dart';

/// 书签数据访问契约；持久化规则由底层实现负责。— Codex + UI
abstract interface class BookmarkRepository {
  Future<List<Bookmark>> getAllBookmarks();

  /// 书名与作者共同标识书籍，避免同名书的书签混入。
  Future<List<Bookmark>> getBookmarksByBook(String bookName, String bookAuthor);

  Future<Bookmark> addBookmark(Bookmark bookmark);

  /// 原子更新已有书签，保留 id 和创建时间，失败保留原记录。
  Future<void> updateBookmark(Bookmark bookmark);

  Future<void> deleteBookmark(int id);

  Future<List<Bookmark>> searchBookmarks(String keyword);
}
