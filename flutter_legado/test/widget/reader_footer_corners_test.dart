import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_legado/src/platform/display/display_corners.dart';
import 'package:flutter_legado/src/features/reader/layout/paragraph_layout_engine.dart';
import 'package:flutter_legado/src/features/reader/layout/reader_footer_geometry.dart';
import 'package:flutter_legado/src/features/reader/widgets/reader_page_chrome.dart';
import 'package:flutter_legado/src/features/reader/widgets/reader_text_content.dart';

void main() {
  const leftPage = ValueKey('左页'), rightPage = ValueKey('右页');
  Widget page({
    Key? key,
    int column = 0,
    int columns = 1,
    double padding = 16,
    int leftTip = 7,
    bool header = false,
  }) => ReaderTypographicPage(
    key: key,
    pageInfo: const PageInfo(paragraphs: [], totalHeight: 0),
    pageIndex: 0,
    totalPages: 10,

    fontSize: 18,
    lineHeight: 1.6,
    paragraphSpacing: 8,
    backgroundColor: Colors.white,
    textColor: Colors.black,
    selectText: false,
    footerColumn: column,
    footerColumns: columns,
    chromeExpansion: header ? const EdgeInsets.only(top: 60) : EdgeInsets.zero,
    pageChrome: ReaderPageChromeConfig(
      headerMode: header ? 1 : 2,
      tipHeaderLeft: 7,
      tipHeaderRight: 1,
      titleMode: 2,
      footerPaddingLeft: padding,
      footerPaddingRight: padding,
      footerPaddingBottom: 10,
      tipFooterLeft: leftTip,
      tipFooterMiddle: 4,
      tipFooterRight: 1,
    ),
    tipContext: const ReaderTipContext(
      bookName: '左侧信息',
      chapterTitle: '右侧信息',
      pageIndex: 0,
      totalPages: 10,
    ),
  );

  Future<void> show(
    WidgetTester tester, {
    bool rounded = true,
    bool doublePage = false,
    double padding = 16,
    double bottom = 0,
    double side = 0,
    Size size = const Size(400, 800),
    int leftTip = 7,
    bool header = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    final corners = DisplayCorners(
      size: size,
      bottomLeft: rounded
          ? DisplayCorner(center: Offset(50, size.height - 50), radius: 50)
          : null,
      bottomRight: rounded
          ? DisplayCorner(
              center: Offset(size.width - 50, size.height - 50),
              radius: 50,
            )
          : null,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderFooterGeometry(
          corners: corners,
          bounds: Rect.fromLTRB(
            side,
            0,
            size.width - side,
            size.height - bottom,
          ),
          child: Scaffold(
            body: Padding(
              padding: EdgeInsets.fromLTRB(side, 0, side, bottom),
              child: doublePage
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: page(
                            key: leftPage,
                            columns: 2,
                            padding: padding,
                          ),
                        ),
                        Expanded(
                          child: page(
                            key: rightPage,
                            column: 1,
                            columns: 2,
                            padding: padding,
                          ),
                        ),
                      ],
                    )
                  : page(padding: padding, leftTip: leftTip, header: header),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('延伸页眉的角落提示横向内收，不改变页眉高度', (tester) async {
    addTearDown(tester.view.reset);
    await show(tester, rounded: false, header: true);
    Finder title() => find.descendant(
      of: find.byType(ReaderPageTipBar).first,
      matching: find.text('左侧信息'),
    );
    final originalX = tester.getTopLeft(title()).dx;
    final originalHeight = tester
        .getSize(find.byType(ReaderPageTipBar).first)
        .height;
    await show(tester, header: true);
    expect(tester.getTopLeft(title()).dx, greaterThan(originalX));
    expect(
      tester.getSize(find.byType(ReaderPageTipBar).first).height,
      originalHeight,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('左右信息自动内收，中间页码、正文几何、分隔线和页脚高度不变', (tester) async {
    addTearDown(tester.view.reset);
    await show(tester, rounded: false);
    final body = tester.getRect(find.byType(ReaderTextContent));
    final footer = tester.getRect(find.byType(ReaderPageTipBar));
    final divider = tester.getRect(find.byType(Divider));
    final center = tester.getCenter(find.text('1/10'));
    expect(tester.getTopLeft(find.text('左侧信息')).dx, 16);
    await show(tester);
    expect(tester.getTopLeft(find.text('左侧信息')).dx, closeTo(24, 0.01));
    expect(tester.getTopRight(find.text('右侧信息')).dx, closeTo(376, 0.01));
    expect(tester.getRect(find.byType(ReaderTextContent)), body);
    expect(tester.getRect(find.byType(ReaderPageTipBar)), footer);
    expect(tester.getRect(find.byType(Divider)), divider);
    expect(tester.getCenter(find.text('1/10')), center);
  });

  testWidgets('用户大边距与已消费的系统安全区不重复补偿', (tester) async {
    addTearDown(tester.view.reset);
    await show(tester, padding: 40);
    expect(tester.getTopLeft(find.text('左侧信息')).dx, 40);
    await show(tester, side: 20, bottom: 30);
    expect(tester.getTopLeft(find.text('左侧信息')).dx, 36);
    expect(tester.getTopRight(find.text('右侧信息')).dx, 364);
  });

  testWidgets('双页只移动屏幕外侧信息，书脊两侧及中间页码不变', (tester) async {
    addTearDown(tester.view.reset);
    await show(tester, doublePage: true);
    Finder text(Key key, String value) =>
        find.descendant(of: find.byKey(key), matching: find.text(value));
    expect(tester.getTopLeft(text(leftPage, '左侧信息')).dx, closeTo(24, 0.01));
    expect(tester.getTopRight(text(leftPage, '右侧信息')).dx, 184);
    expect(tester.getTopLeft(text(rightPage, '左侧信息')).dx, 216);
    expect(tester.getTopRight(text(rightPage, '右侧信息')).dx, closeTo(376, 0.01));
    expect(tester.getCenter(text(leftPage, '1/10')).dx, 100);
    expect(tester.getCenter(text(rightPage, '1/10')).dx, 300);
  });

  testWidgets('旋转按新窗口计算，极窄窗口与时间电量组合不溢出', (tester) async {
    addTearDown(tester.view.reset);
    await show(tester, size: const Size(800, 400));
    expect(tester.getTopRight(find.text('右侧信息')).dx, closeTo(776, 0.01));
    await show(tester, size: const Size(140, 300), padding: 4, leftTip: 8);
    expect(tester.takeException(), isNull);
    expect(tester.getRect(find.byType(ReaderPageTipBar)).bottom, 300);
  });
}
