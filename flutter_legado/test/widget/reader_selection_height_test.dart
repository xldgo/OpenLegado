import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_legado/src/widgets/reader/chapter_layout.dart';
import 'package:flutter_legado/src/widgets/reader/reader_selectable_text.dart';
import 'package:flutter_legado/src/widgets/reader/reader_layout_element.dart';
import 'package:flutter_legado/src/widgets/reader/reader_text_content.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('跨行高亮保留统一行间留白与独立段距，文字缩放 $scale', (tester) async {
      const source = '正文(English)!😀e\u0301第二行正文第三行正文\n第二段正文';
      late PageInfo page;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  // 固定已定稿的主字体行盒，模拟回退文字大于主字体的情况。
                  // 不依赖宿主字体，也不在夹具内重新实现断行。— Codex + UI
                  page = _compactPage(scale, source);
                  return SizedBox(
                    width: 500,
                    child: ReaderTextContent(
                      pageInfo: page,
                      fontSize: 24,
                      lineHeight: 1.2,
                      paragraphSpacing: 8,
                      textColor: Colors.black,
                      justify: false,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      tester
          .state<SelectableRegionState>(find.byType(SelectableRegion))
          .selectAll();
      await tester.pumpAndSettle();
      final paragraphs = find
          .byType(ReaderSelectableText)
          .evaluate()
          .map((element) => element.renderObject! as RenderParagraph)
          .toList();
      final rows = page.paragraphs.expand((p) => p.lines).toList();
      expect(paragraphs.length, greaterThan(3));
      expect(page.paragraphs.length, 2);
      final normalGaps = <double>[];
      double? lastBottom;
      double? height;
      for (var i = 0; i < paragraphs.length; i++) {
        final render = paragraphs[i];
        final boxes = render.getBoxesForSelection(render.selections.single);
        final box = boxes.first;
        final currentHeight = box.bottom - box.top;
        expect(currentHeight, closeTo(16 * scale, 0.01));
        expect(box.top, closeTo(rows[i].glyphs.first.bounds.top, 0.01));
        expect(box.bottom, closeTo(rows[i].glyphs.first.bounds.bottom, 0.01));
        expect(box.left, closeTo(rows[i].glyphs.first.bounds.left, 0.01));
        expect(box.right, closeTo(rows[i].glyphs.last.bounds.right, 0.01));
        height ??= currentHeight;
        expect(currentHeight, closeTo(height, 0.01));
        final origin = render.localToGlobal(Offset.zero).dy;
        if (lastBottom != null) {
          final gap = origin + box.top - lastBottom;
          final paragraphGap = i == page.paragraphs.first.lines.length
              ? 8.0
              : 0.0;
          expect(gap, greaterThan(paragraphGap));
          normalGaps.add(gap - paragraphGap);
        }
        lastBottom = origin + box.bottom;
        expect(currentHeight, lessThanOrEqualTo(rows[i].height));
      }
      for (final gap in normalGaps) {
        expect(gap, closeTo(normalGaps.first, 0.01));
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('中英文符号混排的原生高亮同高，文字缩放 $scale', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SelectionArea(
              child: Builder(
                builder: (context) {
                  // 用不同度量的文字段稳定模拟字体回退，避免依赖主机中文字体。
                  return ReaderSelectableText(
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 24,
                        height: 1.6,
                        color: Colors.black,
                      ),
                      children: [
                        TextSpan(text: '中文'),
                        TextSpan(
                          text: ' ()!? ',
                          style: TextStyle(fontSize: 14),
                        ),
                        TextSpan(text: '正文'),
                      ],
                    ),
                    textScaler: TextScaler.linear(scale),
                    selectionRegistrar: SelectionContainer.maybeOf(context),
                    selectionColor: Colors.blue,
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      tester
          .state<SelectableRegionState>(find.byType(SelectableRegion))
          .selectAll();
      await tester.pumpAndSettle();
      final paragraph = tester.renderObject<RenderParagraph>(
        find.byType(ReaderSelectableText),
      );
      expect(paragraph.selections.single.isCollapsed, isFalse);
      final boxes = paragraph.getBoxesForSelection(paragraph.selections.single);
      expect(boxes.length, greaterThan(1));
      for (final box in boxes) {
        expect(box.top, closeTo(boxes.first.top, 0.01));
        expect(box.bottom, closeTo(boxes.first.bottom, 0.01));
      }
      final chinese = paragraph
          .getBoxesForSelection(
            const TextSelection(baseOffset: 0, extentOffset: 2),
          )
          .single;
      final symbols = paragraph
          .getBoxesForSelection(
            const TextSelection(baseOffset: 3, extentOffset: 7),
          )
          .single;
      expect(symbols.top, closeTo(chinese.top, 0.01));
      expect(symbols.bottom, closeTo(chinese.bottom, 0.01));

      // 只统一纵向边界，字符宽度和选择范围应仍为原生紧贴边界。
      final original = TextPainter(
        text: paragraph.text,
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.linear(scale),
      )..layout();
      final tight = original
          .getBoxesForSelection(
            const TextSelection(baseOffset: 3, extentOffset: 7),
            boxHeightStyle: ui.BoxHeightStyle.tight,
          )
          .single;
      expect(symbols.left, closeTo(tight.left, 0.01));
      expect(symbols.right, closeTo(tight.right, 0.01));
      final full = original.getBoxesForSelection(
        TextSelection(
          baseOffset: 0,
          extentOffset: paragraph.text.toPlainText().length,
        ),
      );
      final top = full.map((box) => box.top).reduce((a, b) => a < b ? a : b);
      final bottom = full
          .map((box) => box.bottom)
          .reduce((a, b) => a > b ? a : b);
      expect(chinese.bottom - chinese.top, closeTo(bottom - top, 0.01));
      original.dispose();
      expect(tester.takeException(), isNull);
    });
  }
}

// 只给定最终行盒、基线和原文范围；较大的实际文字用于暴露选区二次测量。
PageInfo _compactPage(double scale, String source) {
  final texts = [
    ['正文(English)!😀e\u0301', '第二行正文', '第三行正文'],
    ['第二段正文'],
  ];
  var offset = 0;
  final paragraphs = <ParagraphInfo>[];
  for (var p = 0; p < texts.length; p++) {
    final lines = <LineInfo>[];
    for (final text in texts[p]) {
      final start = source.indexOf(text, offset);
      final glyphs = <ReaderGlyph>[];
      var local = 0;
      var x = 0.0;
      for (final cluster in text.characters) {
        glyphs.add(
          ReaderGlyph(
            ReaderLayoutElement(
              ReaderElementKind.text,
              Rect.fromLTWH(x, 0, 16 * scale, 16 * scale),
              {
                'value': cluster,
                'chapterPosition': start + local,
                'paragraphIndex': p,
                'baselinePx': 12 * scale,
              },
            ),
            start,
            Offset.zero,
          ),
        );
        local += cluster.length;
        x += 16 * scale;
      }
      lines.add(
        LineInfo(
          words: text.characters.toList(),
          width: x,
          height: 19.2 * scale,
          baseline: 12 * scale,
          glyphs: glyphs,
          startIndex: start,
          endIndex: start + text.length,
          indentWidth: lines.isEmpty ? 16 * scale : 0,
          isParagraphLastLine: text == texts[p].last,
        ),
      );
      offset = start + text.length;
    }
    paragraphs.add(
      ParagraphInfo(
        lines: lines,
        totalHeight: lines.fold(0.0, (height, line) => height + line.height),
        startIndex: lines.first.startIndex,
        endIndex: lines.last.endIndex,
        chapterParagraphIndex: p + 1,
        spacingBefore: p == 0 ? 0 : 8,
      ),
    );
  }
  return PageInfo(
    paragraphs: paragraphs,
    totalHeight: paragraphs.fold(
      0.0,
      (h, p) => h + p.totalHeight + p.spacingBefore!,
    ),
    sourceText: source,
  );
}
