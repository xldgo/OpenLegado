import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/widgets/bottom_sheet_widget.dart';
import 'package:flutter_legado/src/theme/app_sheet_theme.dart';
import 'package:flutter_legado/src/theme/app_theme.dart';

void main() {
  testWidgets('共用主题控制标题居中，左右操作不等宽时保持居中', (tester) async {
    for (final centered in [true, false]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light.copyWith(
            extensions: [AppSheetTheme(centerTitle: centered)],
          ),
          home: const Scaffold(
            body: SizedBox(
              width: 500,
              child: AppBottomSheet.content(
                title: '居中标题',
                leading: SizedBox(width: 48, child: Icon(Icons.close)),
                trailing: SizedBox(width: 100, child: Text('保存设置')),
                child: Text('内容'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final toolbar = find.byType(NavigationToolbar);
      final title = find.text('居中标题');
      expect(tester.widget<NavigationToolbar>(toolbar).centerMiddle, centered);
      if (centered) {
        expect(
          tester.getCenter(title).dx,
          closeTo(tester.getCenter(find.byType(AppBottomSheet)).dx, 0.01),
        );
      } else {
        expect(
          tester.getCenter(title).dx,
          lessThan(tester.getCenter(find.byType(AppBottomSheet)).dx),
        );
      }
      expect(tester.takeException(), isNull);
    }
  });

  for (final content in [false, true]) {
    testWidgets('默认正文无内边距，设置行长按与边缘点击覆盖整宽 content=$content', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => AppBottomSheet.showContent<void>(
                  context: context,
                  builder: (_) {
                    final row = ListTile(
                      key: const ValueKey('full-width-row'),
                      title: const Text('设置正文'),
                      onTap: () => taps++,
                    );
                    return content
                        ? AppBottomSheet.content(title: '设置', child: row)
                        : AppBottomSheet(title: '设置', children: [row]);
                  },
                ),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      final sheet = tester.getRect(find.byType(AppBottomSheet));
      final row = find.byKey(const ValueKey('full-width-row'));
      final rect = tester.getRect(row);
      expect(rect.left, closeTo(sheet.left, .01));
      expect(rect.right, closeTo(sheet.right, .01));
      final press = await tester.startGesture(
        Offset(rect.left + 2, rect.center.dy),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await press.up();
      await tester.pumpAndSettle();
      await tester.tapAt(Offset(rect.right - 2, rect.center.dy));
      await tester.pumpAndSettle();
      expect(taps, 2);
      expect(tester.takeException(), isNull);
    });
  }

  // [统一壳 B2a] 迁移形态用例：标题 + 操作 ListTile 列表（主题选择/底栏皮肤/
  // 书源操作三处迁移后的共同形态），点击 ListTile 以返回值关闭。
  testWidgets('AppBottomSheet 列表操作项返回值（迁移形态）', (tester) async {
    String? action;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  action = await AppBottomSheet.show<String>(
                    context: context,
                    title: '测试书源',
                    children: [
                      ListTile(
                        leading: const Icon(Icons.arrow_upward),
                        title: const Text('置顶'),
                        onTap: () => Navigator.pop(context, 'top'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.delete),
                        title: const Text('删除'),
                        onTap: () => Navigator.pop(context, 'delete'),
                      ),
                    ],
                  );
                },
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.text('测试书源'), findsOneWidget);
    expect(find.text('置顶'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);

    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(action, 'delete');
    expect(find.text('测试书源'), findsNothing);
  });
}
