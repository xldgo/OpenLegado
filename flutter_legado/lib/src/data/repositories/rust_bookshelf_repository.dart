import '../bridge/rust_errors.dart';
import '../../bridge/business_dto.dart';
import '../bridge/business_dto_mapping.dart';

import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/bookshelf_repository.dart';
import '../../models/book.dart';
import '../bridge/entity_dto_mapping.dart';

/// 直接调用现有 FRB，保留参数、解码与失败语义。— Codex + Bridge
final class RustBookshelfRepository implements BookshelfRepository {
  const RustBookshelfRepository();

  // ========== 书架操作 ==========

  /// 获取书架上所有书籍
  @override
  Future<List<Book>> getBooks() async {
    return (await rustFuture(
      () => bridge.bookshelfList(),
      operation: 'bookshelfList',
    )).map(bookFromDto).toList();
  }

  /// 添加书籍到书架
  @override
  Future<Book> addBook(Book book) async {
    return bookFromDto(
      await rustFuture(
        () => bridge.bookshelfAdd(book: bookToDto(book)),
        operation: 'bookshelfAdd',
      ),
    );
  }

  /// 更新书籍信息
  @override
  Future<void> updateBook(Book book) => rustFuture(
    () => bridge.bookshelfUpdate(book: bookToDto(book)),
    operation: 'bookshelfUpdate',
  );

  @override
  Future<Book> setCanUpdate(String bookUrl, bool canUpdate) async =>
      bookFromDto(
        await rustFuture(
          () => bridge.bookshelfSetCanUpdate(
            bookUrl: bookUrl,
            canUpdate: canUpdate,
          ),
          operation: 'bookshelfSetCanUpdate',
        ),
      );

  /// 从书架删除书籍
  @override
  Future<void> deleteBook(String bookUrl) => rustFuture(
    () => bridge.bookshelfDelete(bookUrl: bookUrl),
    operation: 'bookshelfDelete',
  );

  /// 按 bookUrl 获取书籍详情
  @override
  Future<Book?> getBook(String bookUrl) async {
    final value = await rustFuture(
      () => bridge.bookshelfGet(bookUrl: bookUrl),
      operation: 'bookshelfGet',
    );
    return value == null ? null : bookFromDto(value);
  }

  /// 置顶书籍（通过设置 order 为负值实现）
  @override
  Future<void> topBook(String bookUrl) async {
    final book = await getBook(bookUrl);
    if (book == null) return;
    await rustFuture(
      () => bridge.bookshelfUpdate(book: bookToDto(book.copyWith(order: -1))),
      operation: 'bookshelfUpdate',
    );
  }

  /// 取消置顶（恢复 order 为 0）
  @override
  Future<void> unTopBook(String bookUrl) async {
    final book = await getBook(bookUrl);
    if (book == null) return;
    await rustFuture(
      () => bridge.bookshelfUpdate(book: bookToDto(book.copyWith(order: 0))),
      operation: 'bookshelfUpdate',
    );
  }

  /// 设置书籍分组
  @override
  Future<void> setBookGroup(String bookUrl, int groupId) async {
    final book = await getBook(bookUrl);
    if (book == null) return;
    await rustFuture(
      () => bridge.bookshelfUpdate(
        book: bookToDto(book.copyWith(group: groupId)),
      ),
      operation: 'bookshelfUpdate',
    );
  }

  /// 批量导入书籍，返回成功导入的数量
  @override
  Future<int> importBooks(String jsonArray) => rustFuture(
    () => bridge.bookshelfImport(jsonArray: jsonArray),
    operation: 'bookshelfImport',
  );

  /// 批量持久化书架拖拽排序
  @override
  Future<void> reorderBooks(List<Map<String, dynamic>> orders) => rustFuture(
    () => bridge.bookshelfReorderOrders(
      orders: orders.map((v) {
        final url = v['bookUrl'];
        final order = v['order'];
        if (url is! String || order is! int) {
          throw const FormatException('排序须包含bookUrl和order');
        }
        return BookOrderDto(bookUrl: url, order: businessI32(order));
      }).toList(),
    ),
    operation: 'bookshelfReorderOrders',
  );
}
