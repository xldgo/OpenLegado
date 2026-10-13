import '../../models/misc.dart';

/// 分组定义与显示设置；书籍分组归属由书架接口写入。— Codex + UI
abstract interface class BookGroupRepository {
  Future<List<BookGroup>> getBookGroups();
  Future<BookGroup> addBookGroup(BookGroup group);
  Future<void> updateBookGroup(BookGroup group);
  Future<void> deleteBookGroup(int groupId);
  Future<bool> bookGroupSetShow(int groupId, bool show);
}
