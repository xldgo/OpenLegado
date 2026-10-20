import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/features/toc/application/toc_filter_controller.dart';
import 'package:flutter_legado/src/models/book_chapter.dart';

void main() {
  const chapters = [
    BookChapter(index: 5, title: '第一卷', isVolume: true),
    BookChapter(index: 12, title: 'Chapter One'),
    BookChapter(index: 18, title: '第二章'),
  ];
  testWidgets('搜索防抖、忽略大小写和首尾空白，保留原始位置和实体索引', (tester) async {
    final filter = TocFilterController();
    addTearDown(filter.dispose);
    filter.search('错误');
    await tester.pump(const Duration(milliseconds: 200));
    filter.search(' CHAPTER ');
    await tester.pump(const Duration(milliseconds: 299));
    expect(filter.entries(chapters), hasLength(3));
    await tester.pump(const Duration(milliseconds: 1));
    final result = filter.entries(chapters);
    expect(result.single.key, 1);
    expect(result.single.value.index, 12);
  });
  test('倒序仅修改显示顺序并保留卷和原始实体', () {
    final filter = TocFilterController();
    addTearDown(filter.dispose);
    filter.toggleOrder();
    final result = filter.entries(chapters);
    expect(result.map((e) => e.key), [2, 1, 0]);
    expect(result.last.value.isVolume, isTrue);
    expect(chapters.first.index, 5);
    filter.toggleOrder();
    expect(filter.entries(chapters).first.key, 0);
  });
  testWidgets('清空会取消待执行的搜索，关闭后不再通知', (tester) async {
    final filter = TocFilterController();
    var changes = 0;
    filter.addListener(() => changes++);
    filter.search('第一');
    filter.clear();
    await tester.pump(const Duration(milliseconds: 500));
    expect(filter.query, '');
    expect(changes, 0);
    filter.search('第二');
    filter.dispose();
    await tester.pump(const Duration(milliseconds: 500));
    expect(changes, 0);
  });
}
