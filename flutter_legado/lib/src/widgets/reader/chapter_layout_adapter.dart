import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../services/reader_layout_data.dart';

import 'chapter_layout.dart';
import 'reader_layout_element.dart';
import 'text_layout_environment.dart';

/// 只转换已定稿的页面几何，禁止在适配器中再次断行或拉伸文字。
class ChapterLayoutAdapter {
  final String source;
  final List<SourceParagraph> paragraphs;
  final TextLayoutEnvironment environment;
  final Map<int, InlineReview> reviews;
  final double firstPageInset;
  const ChapterLayoutAdapter({
    required this.source,
    required this.paragraphs,
    required this.environment,
    required this.reviews,
    this.firstPageInset = 0,
  });

  PageInfo convert(Map<String, dynamic> json) {
    final pageIndex = (json['id'] as Map<String, dynamic>)['pageIndex'] as int;
    final inset = pageIndex == 0 ? firstPageInset : 0.0;
    final payload = json['elements'];
    if (payload is! ReaderElementDataList) {
      throw const FormatException('布局适配器需要已校验的共享元素数据');
    }
    final elements = ReaderLayoutElementList(payload);
    final rows = <List<int>>[];
    final reviewByAnchor = <(int, int), ReaderLayoutElement>{};
    for (var index = 0; index < elements.length; index++) {
      final element = elements[index];
      if (element.kind == ReaderElementKind.review) {
        reviewByAnchor[(element.paragraphIndex, element.sourceOffset)] =
            element;
      }
      if (element.kind != ReaderElementKind.text) continue;
      if (rows.isEmpty ||
          elements[rows.last.first].paragraphIndex != element.paragraphIndex ||
          (elements[rows.last.first].top - element.top).abs() > .001) {
        rows.add([]);
      }
      rows.last.add(index);
    }
    final result = <ParagraphInfo>[];
    var previousBottom = 0.0;
    for (final indices in rows) {
      final row = ReaderLineElements(elements, indices);
      final first = row.first;
      final sourceParagraphIndex =
          first.paragraphIndex - (firstPageInset > 0 ? 1 : 0);
      if (sourceParagraphIndex < 0 ||
          sourceParagraphIndex >= paragraphs.length) {
        throw const FormatException('布局段落编号越界');
      }
      final paragraph = paragraphs[sourceParagraphIndex];
      final logicalIndex = sourceParagraphIndex + 1;
      final start = first.sourceOffset;
      final end = row.last.sourceOffset + row.last.text.length;
      final top = first.top - inset;
      final bottom =
          row.fold(first.bottom, (v, e) => math.max(v, e.bottom)) - inset;
      final review = reviewByAnchor[(logicalIndex, end)];
      final height =
          math.max(
            bottom,
            review == null ? bottom : review.bounds.bottom - inset,
          ) -
          top;
      final line = LineInfo(
        words: ReaderLineWords(row),
        width: row.fold(0.0, (v, e) => math.max(v, e.right)),
        height: height,
        startIndex: start,
        endIndex: end,
        indentWidth: first.left,
        letterSpacing: 0,
        baseline: first.baseline - inset - top,
        glyphs: ReaderLineGlyphs(row, start, Offset(first.left, first.top)),
        trailingReview: review == null
            ? null
            : InlineReviewLayout(
                element: reviews[logicalIndex]!,
                offset: Offset(
                  review.bounds.left,
                  review.bounds.top - inset - top,
                ),
                size: review.bounds.size,
                compact:
                    review.bounds.width <
                    reviews[logicalIndex]!.size.width - .001,
              ),
        isParagraphLastLine: end == paragraph.endIndex,
      );
      final gap = math.max(0.0, top - previousBottom);
      if (result.isNotEmpty &&
          result.last.chapterParagraphIndex == logicalIndex &&
          gap < .001) {
        final old = result.removeLast();
        result.add(
          ParagraphInfo(
            lines: List.unmodifiable([...old.lines, line]),
            totalHeight: old.totalHeight + height,
            startIndex: old.startIndex,
            endIndex: end,
            chapterParagraphIndex: logicalIndex,
            isParagraphEnd: end == paragraph.endIndex,
            spacingBefore: old.spacingBefore,
          ),
        );
      } else {
        result.add(
          ParagraphInfo(
            lines: [line],
            totalHeight: height,
            startIndex: start,
            endIndex: end,
            chapterParagraphIndex: logicalIndex,
            isParagraphEnd: end == paragraph.endIndex,
            spacingBefore: gap,
          ),
        );
      }
      previousBottom = top + height;
    }
    return PageInfo(
      paragraphs: List.unmodifiable(result),
      totalHeight: previousBottom,
      sourceText: source,
      textEnvironment: environment,
      elements: elements,
    );
  }
}
