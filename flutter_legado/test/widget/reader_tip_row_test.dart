import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/features/reader/layout/chapter_layout.dart';
import 'package:flutter_legado/src/features/reader/widgets/reader_page_chrome.dart';
import 'package:flutter_legado/src/features/reader/widgets/reader_battery_icon.dart';
import 'package:flutter_legado/src/features/reader/widgets/reader_text_content.dart';

void main() {
  for (final mode in [0, 1, 2]) {
    for (final hidden in [false, true]) {
      testWidgets('页眉模式$mode、系统状态栏隐藏$hidden只有一套提示', (tester) async {
        final visible = mode == 1 || (mode == 0 && hidden);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReaderTypographicPage(
                pageInfo: const PageInfo(paragraphs: [], totalHeight: 0),
                pageIndex: 0,
                totalPages: 1,

                fontSize: 20,
                lineHeight: 1.2,
                paragraphSpacing: 0,
                backgroundColor: Colors.white,
                textColor: Colors.black,
                selectText: false,
                pageChrome: ReaderPageChromeConfig(
                  headerMode: mode,
                  hideStatusBar: hidden,
                  footerMode: 1,
                ),
              ),
            ),
          ),
        );
        expect(
          find.byType(ReaderPageTipBar),
          visible ? findsOneWidget : findsNothing,
        );
        expect(
          find.byType(ReaderBatteryIcon),
          visible ? findsOneWidget : findsNothing,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
  for (final kind in [1, 3]) {
    testWidgets('同行类型$kind重复只显示首槽，保留行高和槽位对齐', (tester) async {
      final battery = ValueNotifier<int?>(25);
      addTearDown(battery.dispose);
      final context = ReaderTipContext(
        pageIndex: 0,
        totalPages: 1,
        chapterTitle: '章节提示',
        battery: battery,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 300,
                child: ReaderPageTipBar(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  leftTip: kind,
                  middleTip: kind,
                  rightTip: kind,
                  tipContext: context,
                  textColor: Colors.black,
                  showDivider: false,
                  dividerOnTop: false,
                ),
              ),
            ),
          ),
        ),
      );
      final tip = kind == 1
          ? find.text('章节提示')
          : find.byType(ReaderBatteryIcon);
      expect(tip, findsOneWidget);
      expect(tester.getTopLeft(tip).dx, closeTo(16, .01));
      expect(
        tester.getSize(find.byType(ReaderPageTipBar)).height,
        greaterThanOrEqualTo(14),
      );
      expect(tester.takeException(), isNull);
      if (kind == 3) {
        for (final level in <int?>[75, 0, null]) {
          battery.value = level;
          await tester.pump();
          expect(tester.widget<ReaderBatteryIcon>(tip).level, level);
          expect(context.batteryText, level == null ? '—' : '$level%');
        }
      }
    });
  }
}
