import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/widgets/reader/chapter_layout.dart';
import 'package:flutter_legado/src/widgets/reader/line_paginator.dart';

ParagraphInfo _paragraph(int start, int count) => ParagraphInfo(
  lines: [
    for (var i = 0; i < count; i++)
      LineInfo(
        words: ['字'],
        width: 10,
        height: 10,
        startIndex: start + i,
        endIndex: start + i + 1,
        isParagraphLastLine: i == count - 1,
      ),
  ],
  startIndex: start,
  endIndex: start + count,
  totalHeight: count * 10,
);

void main() {
  for (final lengths in [
    [6, 6],
    [15, 3],
  ]) {
    test('连续填页 $lengths，长段尾页不封页', () {
      final builder = LinePaginator(
        sourceText: '字' * 18,
        pageHeight: 100,
        paragraphSpacing: 0,
      );
      builder.addParagraph(_paragraph(0, lengths[0]), 1);
      builder.addParagraph(_paragraph(lengths[0], lengths[1]), 2);
      final pages = builder.finish();
      expect(pages.length, 2);
      expect(pages.first.totalHeight, 100);
      final lines = pages
          .expand((p) => p.paragraphs)
          .expand((p) => p.lines)
          .toList();
      expect(
        lines.map((l) => l.startIndex),
        List.generate(lengths[0] + lengths[1], (i) => i),
      );
      expect(
        pages.expand((p) => p.paragraphs).where((p) => p.isParagraphEnd).length,
        2,
      );
    });
  }
  test('真实段距只记一次，跨页续段不重复加段距，首页独立容量', () {
    final builder = LinePaginator(
      sourceText: '字' * 10,
      pageHeight: 50,
      firstPageHeight: 30,
      paragraphSpacing: 5,
    );
    builder.addParagraph(_paragraph(0, 4), 1);
    builder.addParagraph(_paragraph(4, 2), 2);
    final pages = builder.finish();
    expect(pages.map((p) => p.totalHeight), [30, 35]);
    expect(pages[1].paragraphs.map((p) => p.spacingBefore), [0, 5]);
    expect(pages[0].paragraphs.first.isParagraphEnd, isFalse);
    expect(pages[1].paragraphs.first.isParagraphEnd, isTrue);
    expect(pageIndexForSourceOffset(pages, 3), 1);
  });
}
