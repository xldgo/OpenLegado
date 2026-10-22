@Tags(['native'])
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/features/reader/layout/paragraph_layout_engine.dart';
import 'package:flutter_legado/src/features/reader/widgets/reader_page_chrome.dart';
import 'package:flutter_legado/src/features/reader/layout/reader_title_layout.dart';
import 'package:flutter_legado/src/features/reader/selection/reader_selection_controller.dart';
import 'package:flutter_legado/src/features/reader/selection/reader_selection_region.dart';
import 'package:flutter_legado/src/features/reader/widgets/reader_text_content.dart';
import 'package:flutter_legado/src/features/reader/selection/reader_selectable_text.dart';

import '../helpers/native_reader_layout.dart';

class _Context extends Fake implements BuildContext {}

void main() {
  setUpNativeReaderLayout();
  ParagraphLayoutEngine engine() => ParagraphLayoutEngine(
    context: _Context(),
    transport: nativeReaderLayout,
    config: const ParagraphConfig(
      fontSize: 20,
      fontFamily: 'Ahem',
      lineHeight: 1.2,
      paragraphSpacing: 2,
      textBottomJustify: false,
      textColor: Colors.black,
      backgroundColor: Colors.white,
    ),
  );

  test('标题与正文一起分页，原文、选区及段评编号不混入标题', () async {
    const source = 'ABCD\nEFGH';
    final pages = await engine().paginateChapter(
      source,
      160,
      180,
      title: const ReaderTitleLayout(
        text: 'TITLE',
        chrome: ReaderPageChromeConfig(
          titleTopSpacing: 7,
          titleBottomSpacing: 9,
        ),
      ),
      paragraphReviews: const {
        1: InlineReview(
          paragraphId: 1,
          reviewKey: 1,
          sourceAnchor: 4,
          count: 3,
          size: Size(24, 14),
          compactSize: Size(14, 14),
          baseline: 12,
        ),
      },
    );
    final page = pages.single;
    expect(page.sourceText, source);
    expect(page.sourceStart, 0);
    expect(page.sourceEnd, source.length);
    final title = page.paragraphs.firstWhere((p) => p.isTitle);
    expect(title.spacingBefore, closeTo(7, .02));
    expect(title.lines.single.textStyle!.fontSize, 24);
    final body = page.paragraphs.where((p) => !p.isTitle).toList();
    expect(body.first.chapterParagraphIndex, 1);
    expect(body.first.lines.last.trailingReview!.element.reviewKey, 1);
    expect(
      body.expand((p) => p.lines).map((l) => l.selectableText).join(),
      'ABCDEFGH',
    );
    final controller = ReaderSelectionController()
      ..configure(source, pages)
      ..updateRange(0, 8);
    expect(controller.selection!.text, source);
    controller.dispose();
  });

  test('超长标题自然跨页，标题页锚点0不跳到正文页', () async {
    final titleText = 'ABCD' * 30;
    final pages = await engine().paginateChapter(
      '正文',
      120,
      80,
      title: ReaderTitleLayout(
        text: titleText,
        chrome: const ReaderPageChromeConfig(),
      ),
    );
    expect(pages.length, greaterThan(2));
    expect(pages.first.paragraphs.every((p) => p.isTitle), isTrue);
    expect(
      pages
          .expand((p) => p.paragraphs)
          .where((p) => p.isTitle)
          .expand((p) => p.lines)
          .map((l) => l.displayText)
          .join(),
      titleText,
    );
    expect(pageIndexForSourceOffset(pages, 0), 0);
    expect(pages.last.sourceEnd, 2);
    for (final page in pages) {
      expect(page.totalHeight, lessThanOrEqualTo(80.02));
    }
  });

  test('空章即使隐藏标题仍显示且垂直居中，卷章正文保持原文', () async {
    final pages = await engine().paginateChapter(
      '',
      200,
      200,
      title: const ReaderTitleLayout(
        text: 'VOLUME',
        chrome: ReaderPageChromeConfig(titleMode: 2),
      ),
    );
    expect(pages.single.paragraphs.single.isTitle, isTrue);
    expect(pages.single.paragraphs.single.spacingBefore, greaterThan(50));
    final volume = await engine().paginateChapter(
      'AB',
      200,
      200,
      title: const ReaderTitleLayout(
        text: 'VOLUME',
        chrome: ReaderPageChromeConfig(titleMode: 2),
        isVolume: true,
      ),
    );
    expect(volume.single.paragraphs.first.isTitle, isTrue);
    expect(volume.single.sourceEnd, 2);
  });

  test('副标题采用缩放样式及负分段距，正文坐标保持0', () async {
    final pages = await engine().paginateChapter(
      'AB',
      240,
      240,
      title: const ReaderTitleLayout(
        text: 'AAA BBB',
        chrome: ReaderPageChromeConfig(
          titleSegmentType: 1,
          titleSegmentPosition: 3,
          titleSubtitleScale: .5,
          titleSegmentSpacing: -1,
        ),
      ),
    );
    final title = pages.single.paragraphs.where((p) => p.isTitle).toList();
    expect(title, hasLength(2));
    expect(title[0].lines.single.textStyle!.fontSize, 24);
    expect(title[1].lines.single.textStyle!.fontSize, 12);
    expect(title[1].spacingBefore, lessThan(0));
    expect(pages.single.sourceStart, 0);
    expect(pages.single.sourceEnd, 2);
  });

  test('超过32个标题块分批传输，正文仍从第一段开始', () async {
    final title = List.generate(70, (i) => 'TITLE$i').join('\n');
    final pages = await engine().paginateChapter(
      'AB',
      200,
      200,
      title: ReaderTitleLayout(
        text: title,
        chrome: const ReaderPageChromeConfig(),
      ),
    );
    expect(
      pages
          .expand((p) => p.paragraphs)
          .where((p) => p.isTitle)
          .expand((p) => p.lines)
          .map((l) => l.displayText)
          .join(),
      title.replaceAll('\n', ''),
    );
    expect(pages.last.paragraphs.last.chapterParagraphIndex, 1);
    expect(pages.last.sourceEnd, 2);
  });

  for (final segmentSpacing in [-1.0, -3.0]) {
    testWidgets('实际标题按最终字形位置绘制且不注册正文选区，间距$segmentSpacing', (tester) async {
      late PageInfo page;
      await pumpNativeReaderLayout(
        tester,
        MaterialApp(
          home: Scaffold(
            body: LayoutTestBuilder(
              builder: (context) async {
                page = (await engine().paginateChapter(
                  'AB',
                  240,
                  240,
                  title: ReaderTitleLayout(
                    text: 'AAA BBB',
                    chrome: ReaderPageChromeConfig(
                      titleSegmentType: 1,
                      titleSegmentPosition: 3,
                      titleSubtitleScale: .5,
                      titleSegmentSpacing: segmentSpacing,
                      titleFontWeight: 600,
                    ),
                  ),
                )).single;
                return ReaderSelectionRegion(
                  pages: [page],
                  source: 'AB',
                  child: ReaderTextContent(
                    pageInfo: page,
                    fontSize: 20,
                    lineHeight: 1.2,
                    paragraphSpacing: 4,
                    textColor: Colors.black,
                  ),
                );
              },
            ),
          ),
        ),
      );
      final main = find.byWidgetPredicate(
        (w) => w is ReaderSelectableText && w.glyphStyle?.fontSize == 24,
      );
      final sub = find.byWidgetPredicate(
        (w) => w is ReaderSelectableText && w.glyphStyle?.fontSize == 12,
      );
      expect(main, findsOneWidget);
      expect(sub, findsOneWidget);
      expect(
        tester.widget<ReaderSelectableText>(main).glyphStyle!.fontWeight,
        FontWeight.w600,
      );
      expect(SelectionContainer.maybeOf(tester.element(main)), isNull);
      expect(find.byType(ReaderLineText), findsOneWidget);
      expect(
        SelectionContainer.maybeOf(tester.element(find.byType(ReaderLineText))),
        isNotNull,
      );
      final title = page.paragraphs.where((p) => p.isTitle).toList();
      final expected = title[0].totalHeight + title[1].spacingBefore!;
      expect(
        tester.getTopLeft(sub).dy - tester.getTopLeft(main).dy,
        closeTo(expected, .03),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
