import '../helpers/native_reader_layout.dart';

import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_legado/src/widgets/paragraph_layout_engine.dart';
import 'package:flutter_legado/src/widgets/reader/reader_selectable_text.dart';
import 'package:flutter_legado/src/widgets/reader/reader_text_content.dart';

void main() {
  setUpNativeReaderLayout();
  for (final scale in [1.0, 2.0]) {
    testWidgets('跨行高亮保留统一行间留白与独立段距，文字缩放 $scale', (tester) async {
      final source = '${List.filled(8, '正文 (English)! ').join()}\n第二段正文';
      late PageInfo page;
      await pumpNativeReaderLayout(
        tester,
        ProviderScope(
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: LayoutTestBuilder(
                builder: (context) async {
                  page = (await ParagraphLayoutEngine(
                    transport: nativeReaderLayout,
                    context: context,
                    config: ParagraphConfig(
                      fontSize: 16,
                      lineHeight: 1.6,
                      paragraphSpacing: 8,
                      indent: 32,
                      indentCount: 2,
                      hangingPunctuation: true,
                      justify: false,
                      backgroundColor: Colors.white,
                      textColor: Colors.black,
                      baseStyle: DefaultTextStyle.of(context).style,
                      textScaler: MediaQuery.textScalerOf(context),
                    ),
                  ).paginateChapter(source, 500, 560)).first;
                  return SizedBox(
                    width: 500,
                    child: ReaderTextContent(
                      pageInfo: page,
                      fontSize: 16,
                      lineHeight: 1.6,
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
      await settleNativeReaderLayout(tester);
      tester
          .state<SelectableRegionState>(find.byType(SelectableRegion))
          .selectAll();
      await settleNativeReaderLayout(tester);
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
        final painter = TextPainter(
          text: render.text,
          textDirection: TextDirection.ltr,
          textScaler: TextScaler.linear(scale),
          maxLines: 1,
        )..layout();
        final tight = painter.getBoxesForSelection(
          TextSelection(
            baseOffset: 0,
            extentOffset: render.text.toPlainText().length,
          ),
        );
        final tightTop = tight
            .map((b) => b.top)
            .reduce((a, b) => a < b ? a : b);
        final tightBottom = tight
            .map((b) => b.bottom)
            .reduce((a, b) => a > b ? a : b);
        expect(currentHeight, closeTo(tightBottom - tightTop, 0.01));
        painter.dispose();
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
        expect(currentHeight, lessThan(rows[i].height));
      }
      for (final gap in normalGaps) {
        expect(gap, closeTo(normalGaps.first, 0.01));
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('中英文符号混排的原生高亮同高，文字缩放 $scale', (tester) async {
      await pumpNativeReaderLayout(
        tester,
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
      await settleNativeReaderLayout(tester);
      tester
          .state<SelectableRegionState>(find.byType(SelectableRegion))
          .selectAll();
      await settleNativeReaderLayout(tester);
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
