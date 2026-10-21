@Tags(['native'])
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/widgets/paragraph_layout_engine.dart';
import 'package:flutter_legado/src/widgets/reader/reader_text_content.dart';
import 'package:flutter_legado/src/widgets/reader/reader_layout_element.dart';
import 'package:flutter_legado/src/widgets/reader/reader_selectable_text.dart';

import '../helpers/native_reader_layout.dart';

class _Context extends Fake implements BuildContext {}

// 固定字体和逻辑尺寸验证真实Rust分页，不依赖设备截图或重写分页算法。— Codex + UI
void main() {
  setUpNativeReaderLayout();
  final source = 'A' * 200;
  ParagraphLayoutEngine engine({bool bottom = false}) => ParagraphLayoutEngine(
    context: _Context(),
    transport: nativeReaderLayout,
    config: ParagraphConfig(
      fontSize: 20,
      fontFamily: 'Ahem',
      lineHeight: 1.7,
      paragraphSpacing: 0,
      justify: false,
      useZhLayout: false,
      textBottomJustify: bottom,
      backgroundColor: Colors.white,
      textColor: Colors.black,
    ),
  );
  List<LineInfo> rows(PageInfo page) =>
      page.paragraphs.expand((p) => p.lines).toList();

  test('最后一行只需容纳自然行盒，不为行后间隔预留空间', () async {
    final layout = engine();
    expect(layout.shaper.height, closeTo(20, .01));
    final pages = await layout.paginateChapter(source, 200, 610);
    expect(rows(pages.first), hasLength(18));
    expect(pages.first.totalHeight, closeTo(598, .01));
    // 同样34的行推进，旧策略把整个34当行盒只能放17行。
    expect(((610 - 34) / 34).floor() + 1, 17);
    expect(
      pages.expand(rows).map((line) => line.selectableText).join(),
      source,
    );
    expect(rows(pages.first).last.height, closeTo(20, .01));
  });

  test('底部对齐改变间隙而不改变断行、页数及原文范围', () async {
    final natural = await engine().paginateChapter(source, 200, 610);
    final justified = await engine(bottom: true)
        .paginateChapter(source, 200, 610);
    expect(justified.length, natural.length);
    expect(
      rows(justified.first).map((l) => (l.startIndex, l.endIndex)),
      rows(natural.first).map((l) => (l.startIndex, l.endIndex)),
    );
    expect(justified.first.totalHeight, closeTo(610, .01));
    expect(justified.first.elements.first.top, closeTo(0, .01));
    expect(justified.last.totalHeight, natural.last.totalHeight);
  });

  testWidgets('段评行也使用独立行距，最终绘制与原生几何一致且不溢出', (tester) async {
    tester.view.physicalSize = const Size(800, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late PageInfo page;
    await pumpNativeReaderLayout(
      tester,
      MaterialApp(
        home: Scaffold(
          body: LayoutTestBuilder(
            builder: (context) async {
              final layout = engine();
              final pages = await layout.paginateChapter(
                source,
                200,
                610,
                paragraphReviews: {
                  1: InlineReview(
                    paragraphId: 1,
                    reviewKey: 1,
                    sourceAnchor: source.length,
                    count: 3,
                    size: const Size(30, 14),
                    compactSize: const Size(14, 14),
                    baseline: 12,
                  ),
                },
              );
              page = pages.first;
              expect(rows(page), hasLength(18));
              expect(
                pages.expand(rows).where((l) => l.trailingReview != null),
                hasLength(1),
              );
              return Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 200,
                  height: 610,
                  child: ReaderTextContent(
                    pageInfo: page,
                    fontSize: 20,
                    lineHeight: 1.7,
                    paragraphSpacing: 0,
                    fontFamily: 'Ahem',
                    textColor: Colors.black,
                    selectText: false,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    final renderers = find.byType(ReaderSelectableText);
    expect(renderers, findsNWidgets(18));
    final first = tester.getTopLeft(renderers.first).dy;
    final elements = page.elements
        .where((e) => e.kind == ReaderElementKind.text)
        .toList();
    for (var i = 0; i < 18; i++) {
      expect(
        tester.getTopLeft(renderers.at(i)).dy - first,
        closeTo(elements[i * 10].top, .01),
      );
      expect(tester.getSize(renderers.at(i)).height, closeTo(20, .01));
    }
    expect(tester.takeException(), isNull);
  });
  for (final scale in [1.0, 2.0]) {
    for (final withReview in [false, true]) {
      test('自然行高比例段距随缩放变化，段评$withReview，缩放$scale', () async {
        const text = 'AB\nCD';
        final config = const ParagraphConfig(
          fontFamily: 'Ahem',
          fontSize: 20,
          lineHeight: 1.2,
          paragraphSpacing: 2,
          textBottomJustify: false,
          backgroundColor: Colors.white,
          textColor: Colors.black,
        ).copyWith(textScaler: TextScaler.linear(scale));
        final layout = ParagraphLayoutEngine(
          context: _Context(),
          transport: nativeReaderLayout,
          config: config,
        );
        final result = await layout.paginateChapter(
          text,
          300,
          200,
          paragraphReviews: withReview
              ? const {
                  1: InlineReview(
                    paragraphId: 1,
                    reviewKey: 1,
                    sourceAnchor: 2,
                    count: 1,
                    size: Size(24, 14),
                    compactSize: Size(14, 14),
                    baseline: 12,
                  ),
                }
              : const {},
        );
        final page = result.single;
        final h = layout.shaper.height;
        expect(h, closeTo(20 * scale, .01));
        expect(layout.shaper.paragraphSpacingPx, closeTo(h * .2, .01));
        final second = page.elements.firstWhere(
          (element) =>
              element.kind == ReaderElementKind.text &&
              element.sourceOffset == 3,
        );
        expect(second.top, closeTo(h * 1.4, .01));
        expect(page.paragraphs.last.spacingBefore, closeTo(h * .4, .01));
        expect(
          page.paragraphs
              .expand((p) => p.lines)
              .map((line) => line.selectableText)
              .join(),
          'ABCD',
        );
      });
    }
  }
}
