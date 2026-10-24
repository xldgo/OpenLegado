import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../domain/models/reader_layout_data.dart';

import 'chapter_layout.dart';
import 'reader_layout_element.dart';
import 'text_layout_environment.dart';
import 'reader_title_layout.dart';

/// 只转换已定稿的页面几何，禁止在适配器中再次断行或拉伸文字。
class ChapterLayoutAdapter {
  final String source;
  final List<SourceParagraph> paragraphs;
  final TextLayoutEnvironment environment;
  final Map<int, InlineReview> reviews;
  final MeasuredReaderTitle title;
  final double lineHeightMultiplier;
  final double paragraphSpacingPx;
  const ChapterLayoutAdapter({
    required this.source,
    required this.paragraphs,
    required this.environment,
    required this.reviews,
    this.title = MeasuredReaderTitle.empty,
    this.lineHeightMultiplier = 1,
    this.paragraphSpacingPx = 0,
  });

  PageInfo convert(Map<String, dynamic> json) {
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
          (elements[rows.last.first].baseline - element.baseline).abs() >
              .001) {
        rows.add([]);
      }
      rows.last.add(index);
    }
    final result = <ParagraphInfo>[];
    var previousBottom = 0.0;
    var contentBottom = 0.0;
    for (final indices in rows) {
      final row = ReaderLineElements(elements, indices);
      final first = row.first;
      final titleIndex = first.paragraphIndex;
      final isTitle = titleIndex < title.paragraphs.length;
      final sourceParagraphIndex =
          first.paragraphIndex - title.paragraphs.length;
      if (!isTitle &&
          (sourceParagraphIndex < 0 ||
              sourceParagraphIndex >= paragraphs.length)) {
        throw const FormatException('布局段落编号越界');
      }
      final paragraph = isTitle
          ? title.paragraphs[titleIndex]
          : paragraphs[sourceParagraphIndex];
      final logicalIndex = isTitle ? 0 : sourceParagraphIndex + 1;
      final start = first.sourceOffset;
      final end = row.last.sourceOffset + row.last.text.length;
      final top = row.fold(first.top, (v, e) => math.min(v, e.top));
      final bottom = row.fold(first.bottom, (v, e) => math.max(v, e.bottom));
      final review = isTitle ? null : reviewByAnchor[(logicalIndex, end)];
      final height =
          math.max(bottom, review == null ? bottom : review.bounds.bottom) -
          top;
      final line = LineInfo(
        textStyle: isTitle ? title.styles[titleIndex] : null,
        words: ReaderLineWords(row),
        width: row.fold(0.0, (v, e) => math.max(v, e.right)),
        height: height,
        startIndex: start,
        endIndex: end,
        indentWidth: first.left,
        letterSpacing: 0,
        baseline: first.baseline - top,
        glyphs: ReaderLineGlyphs(row, start, Offset(first.left, top)),
        trailingReview: review == null
            ? null
            : InlineReviewLayout(
                element: reviews[logicalIndex]!,
                offset: Offset(review.bounds.left, review.bounds.top - top),
                size: review.bounds.size,
                compact:
                    review.bounds.width <
                    reviews[logicalIndex]!.size.width - .001,
              ),
        isParagraphLastLine: end == paragraph.endIndex,
      );
      final gap = top - previousBottom;
      final atEnd = end == paragraph.endIndex;
      final multiplier = isTitle
          ? (title.blocks[titleIndex]['lineSpacingMultiplier']! as num)
                .toDouble()
          : lineHeightMultiplier;
      var after = height * (multiplier - 1);
      if (atEnd) {
        if (isTitle) {
          final scale = (title.blocks[titleIndex]['titleSpacingScale']! as num)
              .toDouble();
          after +=
              (title.config['titleParagraphSpacingPx']! as num).toDouble() *
              scale;
          after += titleIndex + 1 < title.paragraphs.length
              ? (title.config['titleSegmentSpacingPx']! as num).toDouble() *
                    scale
              : (title.config['titleBottomSpacingPx']! as num).toDouble();
        } else {
          after += paragraphSpacingPx;
        }
      }
      if (result.isNotEmpty &&
          !isTitle &&
          !result.last.isTitle &&
          result.last.chapterParagraphIndex == logicalIndex &&
          gap.abs() < .001) {
        final old = result.removeLast();
        result.add(
          ParagraphInfo(
            isTitle: isTitle,
            continuationSpacingAfter: after,
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
            isTitle: isTitle,
            continuationSpacingAfter: after,
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
      contentBottom = math.max(contentBottom, previousBottom);
    }
    return PageInfo(
      paragraphs: List.unmodifiable(result),
      totalHeight: contentBottom,
      sourceText: source,
      textEnvironment: environment,
      elements: elements,
    );
  }
}
