import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/features/reader/layout/chapter_layout.dart';
import 'package:flutter_legado/src/features/reader/widgets/reader_page_chrome.dart';
import 'package:flutter_legado/src/features/reader/widgets/reader_text_content.dart';
import 'package:flutter_legado/src/features/reader/application/reader_pagination_policy.dart';

void main() {
  testWidgets('提示延伸后正文仍在安全区且不与提示重叠，单页双页测量和绘制一致', (tester) async {
    const viewport = Size(400, 600);
    const bodyInsets = EdgeInsets.fromLTRB(7, 40, 8, 34);
    const margins = EdgeInsets.all(6);
    const chrome = ReaderPageChromeConfig(
      headerMode: 1,
      tipHeaderLeft: 7,
      tipHeaderRight: 0,
      tipFooterLeft: 0,
      tipFooterRight: 4,
    );
    late double measuredHeight;
    Future<void> show({
      required bool extend,
      int columns = 1,
      EdgeInsets safety = bodyInsets,
    }) async {
      final chromeInsets = readerChromeInsets(
        contentInsets: safety,
        systemInsets: safety,
        extendPageTips: extend,
        hideStatusBar: true,
        hideNavigationBar: true,
        centeredHeader: false,
      );
      final expansion = readerChromeExpansion(safety, chromeInsets);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox.fromSize(
                size: viewport,
                child: Builder(
                  builder: (context) {
                    final space = readerPageEdgeSpace(
                      expansion: expansion,
                      headerHeight: ReaderPageLayoutMetrics.headerBlockHeight(
                        context,
                        chrome,
                      ),
                      footerHeight: ReaderPageLayoutMetrics.footerBlockHeight(
                        context,
                        chrome,
                      ),
                    );
                    measuredHeight = ReaderPaginationPolicy.bounds(
                      content: ReaderPaginationPolicy.contentSize(
                        viewport,
                        safety,
                      ),
                      margins: margins,
                      doublePage: columns == 2,
                      headerHeight: space.headerInsideBody,
                      footerHeight: space.footerInsideBody,
                    ).height;
                    return Padding(
                      padding: chromeInsets,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var column = 0; column < columns; column++)
                            Expanded(
                              child: ReaderTypographicPage(
                                pageInfo: const PageInfo(
                                  paragraphs: [],
                                  totalHeight: 0,
                                ),
                                pageIndex: 0,
                                totalPages: 8,
                                fontSize: 20,
                                lineHeight: 1.2,
                                paragraphSpacing: 0,
                                backgroundColor: Colors.white,
                                textColor: Colors.black,
                                pageChrome: chrome,
                                chromeExpansion: expansion,
                                contentPadding: margins,
                                selectText: false,
                                tipContext: const ReaderTipContext(
                                  bookName: '页眉',
                                  pageIndex: 0,
                                  totalPages: 8,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      for (final element in find.byType(ReaderTypographicPage).evaluate()) {
        final page = find.byWidget(element.widget);
        final text = tester.getRect(
          find.descendant(of: page, matching: find.byType(ReaderTextContent)),
        );
        final tips = find.descendant(
          of: page,
          matching: find.byType(ReaderPageTipBar),
        );
        final header = tester.getRect(tips.first);
        final footer = tester.getRect(tips.last);
        expect(text.top, greaterThanOrEqualTo(safety.top));
        expect(text.bottom, lessThanOrEqualTo(viewport.height - safety.bottom));
        expect(text.top, greaterThanOrEqualTo(header.bottom));
        expect(text.bottom, lessThanOrEqualTo(footer.top));
        expect(text.height, closeTo(measuredHeight, .01));
      }
    }

    await show(extend: false);
    final oldHeader = tester.getRect(find.byType(ReaderPageTipBar).first);
    final oldFooter = tester.getRect(find.byType(ReaderPageTipBar).last);
    await show(extend: true);
    expect(
      tester.getTopLeft(find.byType(ReaderPageTipBar).first).dy,
      lessThan(oldHeader.top),
    );
    expect(
      tester.getBottomRight(find.byType(ReaderPageTipBar).last).dy,
      greaterThan(oldFooter.bottom),
    );
    await show(extend: true, columns: 2);
    // 安全区小于提示高度时，正文仍必须给提示留位。
    await show(extend: true, safety: const EdgeInsets.symmetric(vertical: 4));
  });

  testWidgets('隐藏页脚和清空全部提示时零占位，不显示替代页码', (tester) async {
    late double measured;
    Future<double> show(ReaderPageChromeConfig chrome) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 500,
              child: Builder(
                builder: (context) {
                  measured = ReaderPageLayoutMetrics.footerBlockHeight(
                    context,
                    chrome,
                  );
                  return ReaderTypographicPage(
                    pageInfo: const PageInfo(paragraphs: [], totalHeight: 0),
                    pageIndex: 1,
                    totalPages: 8,

                    fontSize: 20,
                    lineHeight: 1.2,
                    paragraphSpacing: 0,
                    backgroundColor: Colors.white,
                    textColor: Colors.black,
                    pageChrome: chrome,
                    selectText: false,
                    tipContext: const ReaderTipContext(
                      pageIndex: 1,
                      totalPages: 8,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      return tester.getSize(find.byType(ReaderTextContent)).height;
    }

    final visible = await show(const ReaderPageChromeConfig(headerMode: 2));
    final visibleFooter = measured;
    expect(visibleFooter, greaterThan(0));
    final hidden = await show(
      const ReaderPageChromeConfig(headerMode: 2, footerMode: 1),
    );
    expect(measured, 0);
    expect(hidden, closeTo(500 - 12, .01));
    expect(hidden - visible, closeTo(visibleFooter, .01));
    expect(find.byType(ReaderPageTipBar), findsNothing);
    expect(find.text('2/8'), findsNothing);
    final empty = await show(
      const ReaderPageChromeConfig(
        headerMode: 2,
        tipFooterLeft: 0,
        tipFooterMiddle: 0,
        tipFooterRight: 0,
      ),
    );
    expect(measured, 0);
    expect(empty, hidden);
    expect(find.byType(ReaderPageTipBar), findsNothing);
    expect(find.text('2/8'), findsNothing);
  });
}
