import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/features/reader/layout/chapter_layout.dart';
import 'package:flutter_legado/src/features/reader/layout/chapter_pagination_session.dart';

void main() {
  test('完整章节缓存按实际访问淘汰，不存可变页面列表', () {
    final cache = ChapterLayoutCache(capacity: 2);
    final pages = <PageInfo>[const PageInfo(paragraphs: [], totalHeight: 10)];
    cache.put('甲', pages);
    pages.clear();
    cache.put('乙', []);
    expect(cache.get('甲'), hasLength(1));
    cache.put('丙', []);
    expect(cache.get('乙'), isNull);
    expect(cache.get('甲'), hasLength(1));
    expect(cache.length, 2);
    expect(() => cache.get('甲')!.clear(), throwsUnsupportedError);
  });
  test('章节缓存按估算字节预算淘汰，超大章节不进入缓存，替换和清空释放额度', () {
    const page = PageInfo(paragraphs: [], totalHeight: 10, sourceText: '缓存正文');
    final cost = ChapterLayoutCache.estimateBytes([page]);
    final cache = ChapterLayoutCache(capacity: 10, byteBudget: cost * 2);
    cache.put('甲', [page]);
    cache.put('乙', [page]);
    expect(cache.retainedBytes, cost * 2);
    cache.get('甲');
    cache.put('丙', [page]);
    expect(cache.get('乙'), isNull);
    expect(cache.get('甲'), hasLength(1));
    expect(cache.retainedBytes, lessThanOrEqualTo(cache.byteBudget));
    cache.put('超大', [
      PageInfo(paragraphs: [], totalHeight: 10, sourceText: '正文' * 1000),
    ]);
    expect(cache.get('超大'), isNull);
    expect(cache.get('甲'), hasLength(1));
    expect(cache.length, 2);
    cache.put('甲', []);
    expect(cache.retainedBytes, cost + ChapterLayoutCache.estimateBytes([]));
    cache.clear();
    expect(cache.retainedBytes, 0);
    expect(cache.length, 0);
    expect(() => ChapterLayoutCache(capacity: 0), throwsArgumentError);
    expect(() => ChapterLayoutCache(byteBudget: 0), throwsArgumentError);
  });
}
