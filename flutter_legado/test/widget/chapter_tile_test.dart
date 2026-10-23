import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_legado/src/widgets/chapter_tile.dart';

void main() {
  Widget buildTestWidget({
    String title = '第一章 开始',
    bool isRead = false,
    bool isCurrent = false,
    VoidCallback? onTap,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: ListView(
          children: [
            ChapterTile(
              title: title,
              isRead: isRead,
              isCurrent: isCurrent,
              onTap: onTap,
            ),
          ],
        ),
      ),
    );
  }

  testWidgets('ChapterTile shows play icon when isCurrent', (tester) async {
    await tester.pumpWidget(buildTestWidget(isCurrent: true));

    expect(find.byIcon(Symbols.play_arrow_rounded), findsOneWidget);
  });

  testWidgets('ChapterTile hides play icon when not current', (tester) async {
    await tester.pumpWidget(buildTestWidget(isCurrent: false));

    expect(find.byIcon(Symbols.play_arrow_rounded), findsNothing);
  });
}
