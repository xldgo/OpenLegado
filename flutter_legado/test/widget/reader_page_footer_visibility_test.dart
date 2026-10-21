import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/widgets/reader/chapter_layout.dart';
import 'package:flutter_legado/src/widgets/reader/reader_page_chrome.dart';
import 'package:flutter_legado/src/widgets/reader/reader_text_content.dart';

void main() {
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
