import 'dart:convert';

import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/bookshelf_repository.dart';
import '../../models/book.dart';
import '../bridge/rust_json_decode.dart';

/// 直接调用现有 FRB，保留参数、解码与失败语义。— Codex + Bridge
final class RustBookshelfRepository implements BookshelfRepository {
  const RustBookshelfRepository();

  // ========== 书架操作 ==========

  /// 获取书架上所有书籍
  @override
  Future<List<Book>> getBooks() async {
    final json = await bridge.bookshelfList();
    final list = decodeRustJsonList(json, 'bookApi');
    return list.map((e) => Book.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// 添加书籍到书架
  @override
  Future<Book> addBook(Book book) async {
    final json = await bridge.bookshelfAdd(bookJson: jsonEncode(book.toJson()));
    return Book.fromJson(decodeRustJsonMap(json, 'bookApi'));
  }

  /// 更新书籍信息
  @override
  Future<void> updateBook(Book book) =>
      bridge.bookshelfUpdate(bookJson: jsonEncode(book.toJson()));

  /// 从书架删除书籍
  @override
  Future<void> deleteBook(String bookUrl) =>
      bridge.bookshelfDelete(bookUrl: bookUrl);

  /// 按 bookUrl 获取书籍详情
  @override
  Future<Book?> getBook(String bookUrl) async {
    final json = await bridge.bookshelfGet(bookUrl: bookUrl);
    if (json.isEmpty || json == 'null') return null;
    return Book.fromJson(decodeRustJsonMap(json, 'bookApi'));
  }

  /// 置顶书籍（通过设置 order 为负值实现）
  @override
  Future<void> topBook(String bookUrl) async {
    final book = await getBook(bookUrl);
    if (book == null) return;
    await bridge.bookshelfUpdate(
      bookJson: jsonEncode(book.copyWith(order: -1).toJson()),
    );
  }

  /// 取消置顶（恢复 order 为 0）
  @override
  Future<void> unTopBook(String bookUrl) async {
    final book = await getBook(bookUrl);
    if (book == null) return;
    await bridge.bookshelfUpdate(
      bookJson: jsonEncode(book.copyWith(order: 0).toJson()),
    );
  }

  /// 设置书籍分组
  @override
  Future<void> setBookGroup(String bookUrl, int groupId) async {
    final book = await getBook(bookUrl);
    if (book == null) return;
    await bridge.bookshelfUpdate(
      bookJson: jsonEncode(book.copyWith(group: groupId).toJson()),
    );
  }

  /// 批量导入书籍，返回成功导入的数量
  @override
  Future<int> importBooks(String jsonArray) =>
      bridge.bookshelfImport(jsonArray: jsonArray);

  /// 批量持久化书架拖拽排序
  @override
  Future<void> reorderBooks(List<Map<String, dynamic>> orders) =>
      bridge.bookshelfReorderOrders(ordersJson: jsonEncode(orders));
}
