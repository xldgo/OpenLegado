import '../../domain/contracts/book_group_repository.dart';
import '../../models/misc.dart';

/// 唯一 Mock 分组列表，种子和 ID 分配沿用应用装配。— Codex + Bridge
final class MockBookGroupRepository implements BookGroupRepository {
  MockBookGroupRepository({
    required this._nextId,
    bool withDefaultGroups = false,
  }) {
    if (withDefaultGroups) {
      _groups.addAll(const [
        BookGroup(groupId: 1, groupName: '科幻', order: 0, show: true),
        BookGroup(groupId: 2, groupName: '收藏', order: 1, show: true),
      ]);
    }
  }
  final int Function() _nextId;
  final List<BookGroup> _groups = [];

  // ========== 书籍分组 ==========

  @override
  Future<List<BookGroup>> getBookGroups() async => List.from(_groups);

  @override
  Future<BookGroup> addBookGroup(BookGroup group) async {
    final g = group.copyWith(groupId: _nextId());
    _groups.add(g);
    return g;
  }

  @override
  Future<void> updateBookGroup(BookGroup group) async {
    final idx = _groups.indexWhere((g) => g.groupId == group.groupId);
    if (idx >= 0) _groups[idx] = group;
  }

  @override
  Future<void> deleteBookGroup(int groupId) async {
    _groups.removeWhere((g) => g.groupId == groupId);
  }

  @override
  Future<bool> bookGroupSetShow(int groupId, bool show) async => true;
}
