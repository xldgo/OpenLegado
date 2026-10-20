import '../bridge/rust_errors.dart';
import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/book_group_repository.dart';
import '../../models/misc.dart';
import '../bridge/reading_dto_mapping.dart';

/// 直接映射现有分组字段，保留参数与失败语义。— Codex + Bridge
final class RustBookGroupRepository implements BookGroupRepository {
  const RustBookGroupRepository();

  // ========== 书籍分组 ==========

  /// 获取所有书籍分组
  @override
  Future<List<BookGroup>> getBookGroups() async {
    return (await rustFuture(
      () => bridge.bookGroupList(),
      operation: 'bookGroupList',
    )).map(bookGroupFromDto).toList();
  }

  /// 添加书籍分组
  @override
  Future<BookGroup> addBookGroup(BookGroup group) async {
    final id = await rustFuture(
      () => bridge.bookGroupAdd(
        groupName: group.groupName,
        cover: group.cover ?? '',
        order: group.order,
        isPrivate: group.isPrivate,
      ),
      operation: 'bookGroupAdd',
    );
    return group.copyWith(groupId: id.toInt());
  }

  /// 更新书籍分组
  @override
  Future<void> updateBookGroup(BookGroup group) async {
    await rustFuture(
      () => bridge.bookGroupUpdate(
        id: group.groupId,
        groupName: group.groupName,
        cover: group.cover ?? '',
        order: group.order,
        isPrivate: group.isPrivate,
      ),
      operation: 'bookGroupUpdate',
    );
  }

  /// 删除书籍分组
  @override
  Future<void> deleteBookGroup(int groupId) async {
    await rustFuture(
      () => bridge.bookGroupDelete(id: groupId),
      operation: 'bookGroupDelete',
    );
  }

  /// 设置分组显示状态（F3-20）
  @override
  Future<bool> bookGroupSetShow(int groupId, bool show) => rustFuture(
    () => bridge.bookGroupSetShow(id: groupId, show_: show),
    operation: 'bookGroupSetShow',
  );
}
