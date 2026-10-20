import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/widgets/top_bar_button.dart';
import 'package:flutter_legado/src/domain/models/ui_settings.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('顶栏按钮在$brightness主题具有可读标签和足够点击区域', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        var taps = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: Scaffold(
              body: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final style in TopBarButtonStyle.values)
                      TopBarButton(
                        icon: Icons.search,
                        tooltip: '搜索 ${style.name}',
                        style: style,
                        onPressed: () => taps++,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await tester.tap(find.byType(IconButton).first);
        await tester.pump();
        expect(taps, 1);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });
  }
}
