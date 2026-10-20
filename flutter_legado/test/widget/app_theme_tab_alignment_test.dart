import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_legado/src/theme/app_theme.dart';

void main() {
  for (final dark in [false, true]) {
    for (final scrollable in [false, true]) {
      testWidgets(
        '${dark ? '深色' : '浅色'}应用主题允许${scrollable ? '可滚动' : '固定'} Tab 正常切换',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? AppTheme.dark : AppTheme.light,
              home: DefaultTabController(
                length: 2,
                child: Scaffold(
                  appBar: AppBar(
                    bottom: TabBar(
                      isScrollable: scrollable,
                      tabs: const [
                        Tab(text: '音色'),
                        Tab(text: '引擎'),
                      ],
                    ),
                  ),
                  body: const TabBarView(
                    children: [Text('音色内容'), Text('引擎内容')],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.tap(find.widgetWithText(Tab, '引擎'));
          await tester.pumpAndSettle();
          final context = tester.element(find.byType(TabBar));
          expect(DefaultTabController.of(context).index, 1);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
