import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/widgets/reader/reader_page_chrome.dart';
import 'package:flutter_legado/src/widgets/reader/reader_title_layout.dart';
import 'package:flutter_legado/src/widgets/reader/text_layout_environment.dart';

void main() {
  for (final relative in [true, false]) {
    testWidgets('标题测量与绘制同参，相对模式$relative', (tester) async {
      late ReaderTitleLayout layout;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (context) {
                  layout = ReaderTitleLayout(
                    chrome: ReaderPageChromeConfig(
                      titleSize: 12,
                      titleSizeRelative: relative,
                      titleFontWeight: 600,
                      titleLineHeight: 1.5,
                      titleMode: 1,
                      titleTopSpacing: 7,
                      titleBottomSpacing: 9,
                    ),
                    environment: TextLayoutEnvironment.of(
                      context,
                      textScaler: const TextScaler.linear(1.5),
                    ),
                    bodySize: 20,
                    bodyFont: 'Ahem',
                    color: Colors.black,
                    letterSpacingEm: .1,
                  );
                  return SizedBox(
                    width: 160,
                    child: layout.build('ABCD EFGH IJKL'),
                  );
                },
              ),
            ),
          ),
        ),
      );
      final text = tester.widget<Text>(find.text('ABCD EFGH IJKL'));
      expect(text.style!.fontSize, relative ? 32 : 12);
      expect(text.style!.fontWeight, FontWeight.w600);
      expect(text.style!.letterSpacing, closeTo(relative ? 3.2 : 1.2, .001));
      expect(text.textAlign, TextAlign.center);
      final title = find
          .ancestor(
            of: find.text('ABCD EFGH IJKL'),
            matching: find.byType(Padding),
          )
          .first;
      expect(
        tester.getSize(title).height,
        closeTo(layout.measure('ABCD EFGH IJKL', 160), .01),
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('标题隐藏不绘制且不占测量高度', (tester) async {
    late ReaderTitleLayout layout;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            layout = ReaderTitleLayout(
              chrome: const ReaderPageChromeConfig(titleMode: 2),
              environment: TextLayoutEnvironment.of(context),
              bodySize: 20,
              color: Colors.black,
            );
            return layout.build('隐藏标题');
          },
        ),
      ),
    );
    expect(find.text('隐藏标题'), findsNothing);
    expect(layout.measure('隐藏标题', 300), 0);
  });
}
