import 'package:flutter/widgets.dart';
import 'package:flutter_legado/src/widgets/reader/chapter_layout.dart';
import 'package:flutter_legado/src/widgets/reader/reader_layout_element.dart';
import 'package:flutter_legado/src/widgets/reader/text_layout_environment.dart';

/// 行和分页由用例明确给定，只测量已给定行的字体几何，不实现断行或分页。
/// 供正文渲染与选区测试使用，不作为排版算法的预期生成器。— Codex + UI
PageInfo readerPageFixture(
  BuildContext context, {
  required String source,
  required List<List<String>> paragraphs,
  int sourceStart = 0,
  int firstParagraphIndex = 1,
  double indent = 32,
}) {
  final environment = TextLayoutEnvironment.of(context);
  final style = environment.baseStyle.merge(
    const TextStyle(fontSize: 16, height: 1.6, letterSpacing: 0),
  );
  var cursor = sourceStart;
  var totalHeight = 0.0;
  final result = <ParagraphInfo>[];
  for (var p = 0; p < paragraphs.length; p++) {
    final texts = paragraphs[p];
    final lines = <LineInfo>[];
    for (var i = 0; i < texts.length; i++) {
      final text = texts[i];
      final start = source.indexOf(text, cursor);
      if (text.isEmpty ||
          start < 0 ||
          source.substring(cursor, start).trim().isNotEmpty) {
        throw ArgumentError('布局夹具必须按原文顺序给定非空行，不得跳过正文');
      }
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: environment.direction,
        textScaler: environment.textScaler,
        locale: environment.locale,
        textHeightBehavior: environment.heightBehavior,
      )..layout();
      final baseline = painter.computeDistanceToActualBaseline(
        TextBaseline.alphabetic,
      );
      var offset = 0;
      final glyphs = <ReaderGlyph>[];
      for (final cluster in text.characters) {
        final boxes = painter.getBoxesForSelection(
          TextSelection(
            baseOffset: offset,
            extentOffset: offset + cluster.length,
          ),
        );
        final bounds = boxes
            .map((box) => box.toRect())
            .reduce((a, b) => a.expandToInclude(b));
        final element = ReaderLayoutElement(
          ReaderElementKind.text,
          Rect.fromLTRB(bounds.left, 0, bounds.right, painter.height),
          {
            'value': cluster,
            'chapterPosition': start + offset,
            'paragraphIndex': firstParagraphIndex + p - 1,
            'baselinePx': baseline,
          },
        );
        glyphs.add(ReaderGlyph(element, start, Offset.zero));
        offset += cluster.length;
      }
      lines.add(
        LineInfo(
          words: text.characters.toList(),
          width: painter.width,
          height: painter.height,
          baseline: baseline,
          glyphs: glyphs,
          startIndex: start,
          endIndex: start + text.length,
          indentWidth: i == 0 ? indent : 0,
          letterSpacing: 0,
          isParagraphLastLine: i == texts.length - 1,
        ),
      );
      painter.dispose();
      cursor = start + text.length;
    }
    final height = lines.fold(0.0, (sum, line) => sum + line.height);
    final spacing = p == 0 ? 0.0 : 8.0;
    totalHeight += height + spacing;
    result.add(
      ParagraphInfo(
        lines: lines,
        totalHeight: height,
        startIndex: lines.first.startIndex,
        endIndex: lines.last.endIndex,
        chapterParagraphIndex: firstParagraphIndex + p,
        spacingBefore: spacing,
      ),
    );
  }
  return PageInfo(
    paragraphs: result,
    totalHeight: totalHeight,
    sourceText: source,
    textEnvironment: environment,
  );
}
