import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_legado/src/widgets/navigation/app_navigation_bars.dart';
import 'package:flutter_legado/src/theme/app_theme.dart';

const specs = [
  AppNavSpec(symbol: Symbols.home_rounded, label: '首页'),
  AppNavSpec(symbol: Symbols.menu_book_rounded, label: '书架'),
  AppNavSpec(symbol: Symbols.explore_rounded, label: '发现'),
  AppNavSpec(symbol: Symbols.rss_feed_rounded, label: '订阅'),
  AppNavSpec(symbol: Symbols.person_rounded, label: '我的'),
];

void main() {
  testWidgets('导航轨头部与正文跟随同一动画，宽度不瞬间跳到终点', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var expanded = false;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Scaffold(
              body: Row(
                children: [
                  AppRailBar(
                    specs: specs,
                    currentIndex: 1,
                    activeSkin: '',
                    extended: expanded,
                    onSelect: (_) {},
                    onToggleExtended: () =>
                        setState(() => expanded = !expanded),
                    onSearch: () {},
                  ),
                  const Expanded(child: SizedBox(key: ValueKey('rail-body'))),
                ],
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final rail = find.byType(NavigationRail);
    final body = find.byKey(const ValueKey('rail-body'));
    expect(tester.getSize(rail).width, 80);
    await tester.tap(find.byTooltip('展开侧栏'));
    await tester.pump();
    expect(tester.getSize(rail).width, 80);
    await tester.pump(const Duration(milliseconds: 80));
    final middleWidth = tester.getSize(rail).width;
    expect(middleWidth, greaterThan(80));
    expect(middleWidth, lessThan(200));
    expect(tester.getSize(body).width, closeTo(800 - middleWidth, 0.01));
    await tester.pumpAndSettle();
    expect(tester.getSize(rail).width, 200);
    update(() => expanded = false);
    await tester.pump();
    expect(tester.getSize(rail).width, 200);
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.getSize(rail).width, greaterThan(80));
    expect(tester.getSize(rail).width, lessThan(200));
    await tester.pumpAndSettle();
    expect(tester.getSize(rail).width, 80);
    expect(tester.takeException(), isNull);
  });

  for (final expanded in [false, true]) {
    testWidgets('横屏导航轨${expanded ? '展开' : '折叠'}可滚动到所有页面', (tester) async {
      tester.view.physicalSize = const Size(640, 280);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      int? destination;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
              child: Row(
                children: [
                  AppRailBar(
                    specs: specs,
                    currentIndex: 1,
                    activeSkin: '',
                    extended: expanded,
                    onSelect: (index) => destination = index,
                    onToggleExtended: () {},
                    onSearch: () {},
                  ),
                  const Expanded(child: SizedBox()),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('书架分组'), findsNothing);
      final rail = find.byType(NavigationRail);
      expect(tester.getSize(rail).width, expanded ? 200 : 80);
      final scroller = find.descendant(
        of: rail,
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.byTooltip('我的'),
        100,
        scrollable: scroller,
      );
      await tester.tap(find.byTooltip('我的'));
      await tester.pumpAndSettle();
      expect(destination, 4);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('长按书架打开分组，普通点击仍切换书架', (tester) async {
    int? destination;
    int? group;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              AppRailBar(
                specs: specs,
                currentIndex: 0,
                activeSkin: '',
                extended: false,
                bookshelfIndex: 1,
                groups: const ['全部', '小说'],
                selectedGroupIndex: 0,
                onGroupSelected: (index) => group = index,
                onSelect: (index) => destination = index,
                onToggleExtended: () {},
                onSearch: () {},
              ),
              const Expanded(child: SizedBox()),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final icon = find.byKey(const ValueKey('rail-bookshelf-groups'));
    await tester.tap(icon);
    await tester.pumpAndSettle();
    expect(destination, 1);
    await tester.longPress(icon);
    await tester.pumpAndSettle();
    await tester.tap(find.text('小说'));
    await tester.pumpAndSettle();
    expect(group, 1);
    expect(find.text('小说'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
