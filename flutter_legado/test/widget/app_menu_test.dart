import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/widgets/app_menu.dart';
import 'package:flutter_legado/src/widgets/pill_divider.dart';

/// 既有菜单回归迁移：选择、空值筛选及系统返回保持原行为。
void main() {
  testWidgets('选中菜单项后回传原值并关闭菜单', (tester) async {
    int? selected;
    final localTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Theme(
              data: localTheme,
              child: AppMenuButton<int>(
                child: const Text('打开菜单'),
                itemBuilder: (_) => const [
                  AppMenuItem(value: 1, child: Text('第一项')),
                  AppMenuDivider(),
                  AppMenuItem(value: 2, checked: true, child: Text('第二项')),
                ],
                onSelected: (value) => selected = value,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开菜单'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.widgetWithText(MenuItemButton, '第一项')))
          .colorScheme,
      localTheme.colorScheme,
    );
    await tester.tap(find.text('第二项'));
    await tester.pumpAndSettle();
    expect(selected, 2);
    expect(find.text('第一项'), findsNothing);
    expect(find.text('第二项'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('禁用标题不触发操作，空值菜单项仍可清除筛选', (tester) async {
    var called = false;
    String? selected = '原分组';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AppMenuButton<String?>(
              child: const Text('分组'),
              itemBuilder: (_) => const [
                AppMenuItem(enabled: false, child: Text('分组标题')),
                AppMenuItem(value: null, child: Text('全部分组')),
              ],
              onSelected: (value) {
                called = true;
                selected = value;
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('分组'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('分组标题'));
    await tester.pumpAndSettle();
    expect(called, isFalse);
    expect(find.text('全部分组'), findsOneWidget);
    await tester.tap(find.text('全部分组'));
    await tester.pumpAndSettle();
    expect(called, isTrue);
    expect(selected, isNull);
    expect(find.text('全部分组'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('系统返回关闭菜单后保留当前页面且可再次打开', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AppMenuButton<int>(
              child: const Text('当前页面菜单'),
              itemBuilder: (_) => const [
                AppMenuItem(value: 1, child: Text('菜单操作')),
              ],
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('当前页面菜单'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('当前页面菜单'), findsOneWidget);
    expect(find.text('菜单操作'), findsNothing);
    await tester.tap(find.text('当前页面菜单'));
    await tester.pumpAndSettle();
    expect(find.text('菜单操作'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PillDivider enabled=false 时不渲染（与既有语义一致）', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: PillDivider(enabled: false))),
      ),
    );
    expect(find.byType(FractionallySizedBox), findsNothing);
  });
}
