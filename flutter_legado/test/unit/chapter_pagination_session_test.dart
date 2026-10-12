import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/widgets/reader/chapter_layout.dart';
import 'package:flutter_legado/src/widgets/reader/line_paginator.dart';
import 'package:flutter_legado/src/widgets/reader/chapter_pagination_session.dart';

void main() {
  test('分批先发布完整页面，取消后停止测量，尾页只在结束时提交', () {
    var calls = 0;
    final session = ChapterPaginationSession(
      paragraphs: List.generate(10, (i) => SourceParagraph('甲', i, i + 1)),
      paginator: LinePaginator(
        sourceText: '甲' * 10,
        pageHeight: 20,
        paragraphSpacing: 0,
      ),
      measure: (paragraph, index) {
        calls++;
        return ParagraphInfo(
          lines: [
            LineInfo(
              words: const ['甲'],
              width: 10,
              height: 10,
              startIndex: paragraph.startIndex,
              endIndex: paragraph.endIndex,
            ),
          ],
          totalHeight: 10,
          startIndex: paragraph.startIndex,
          endIndex: paragraph.endIndex,
        );
      },
    );
    session.advance(maxParagraphs: 3, budget: const Duration(seconds: 1));
    expect(session.pages, hasLength(1));
    expect(session.pages.first.sourceEnd, 2);
    expect(session.complete, isFalse);
    session.cancel();
    session.advance();
    expect(calls, 3);
    expect(session.complete, isFalse);
  });

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
}
