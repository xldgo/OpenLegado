import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/services/mock_book_api.dart';

void main() {
  test('Mock 连续更新同一书签，保留 id 与创建时间', () async {
    final api = MockBookApi();
    final added = await api.addBookmark(
      const Bookmark(bookName: '更新测试', time: 12345, content: '原备注'),
    );
    await api.updateBookmark(added.copyWith(time: 0, content: '新备注'));
    await api.updateBookmark(added.copyWith(time: 999, content: '再次更新'));
    final found = await api.getBookmarks('更新测试');
    expect(found, [added.copyWith(content: '再次更新')]);
  });

  test('Mock 更新不存在的书签时报错且不修改其他记录', () async {
    final api = MockBookApi();
    final before = await api.getAllBookmarks();
    await expectLater(
      api.updateBookmark(const Bookmark(id: -1, content: '不存在')),
      throwsStateError,
    );
    expect(await api.getAllBookmarks(), before);
  });
}
