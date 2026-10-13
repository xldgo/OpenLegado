import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/book_group_repository.dart';
import '../../models/misc.dart';
import '../bridge/rust_json_decode.dart';

/// 直接调用现有 FRB，保留参数、解码与失败语义。— Codex + Bridge
final class RustBookGroupRepository implements BookGroupRepository {
  const RustBookGroupRepository();

  // ========== 书籍分组 ==========

  /// 获取所有书籍分组
  @override
  Future<List<BookGroup>> getBookGroups() async {
    final json = await bridge.bookGroupList();
    final list = decodeRustJsonList(json, 'bookApi');
    return list
        .map((e) => BookGroup.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 添加书籍分组
  @override
  Future<BookGroup> addBookGroup(BookGroup group) async {
    final id = await bridge.bookGroupAdd(
      groupName: group.groupName,
      cover: group.cover ?? '',
      order: group.order,
    );
    return group.copyWith(groupId: id.toInt());
  }

  /// 更新书籍分组
  @override
  Future<void> updateBookGroup(BookGroup group) async {
    await bridge.bookGroupUpdate(
      id: group.groupId,
      groupName: group.groupName,
      cover: group.cover ?? '',
      order: group.order,
    );
  }

  /// 删除书籍分组
  @override
  Future<void> deleteBookGroup(int groupId) async {
    await bridge.bookGroupDelete(id: groupId);
  }

  /// 设置分组显示状态（F3-20）
  @override
  Future<bool> bookGroupSetShow(int groupId, bool show) =>
      bridge.bookGroupSetShow(id: groupId, show_: show);
}
