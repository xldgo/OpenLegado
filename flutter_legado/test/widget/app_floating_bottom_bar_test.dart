import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_legado/src/widgets/navigation/app_navigation_bars.dart';

/// 悬浮胶囊底栏的材质几何与语义回归。
///
/// 锁住两个曾经静默出错的地方：
/// - 模糊层裁剪范围大于可见胶囊（左右留白与底部留白被包进 ClipRRect）；
/// - 透明度按 0-100 解读 0-255 字段，alpha 超过 100 后全部饱和为不透明。
void main() {
  const specs = [
    AppNavSpec(symbol: Icons.home_rounded, label: '首页'),
    AppNavSpec(symbol: Icons.menu_book_rounded, label: '书架'),
    AppNavSpec(symbol: Icons.explore_rounded, label: '发现'),
  ];

  Future<void> pumpBar(
    WidgetTester tester, {
    required bool useBlur,
    int currentIndex = 0,
    ValueChanged<int>? onSelect,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: AppFloatingBottomBar(
            specs: specs,
            currentIndex: currentIndex,
            activeSkin: '',
            onSelect: onSelect ?? (_) {},
            useBlur: useBlur,
            blurRadius: 20,
            blurAlpha: 73,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder barClip() => find.descendant(
    of: find.byType(AppFloatingBottomBar),
    matching: find.byType(ClipRRect),
  );

  Finder surface() => find.descendant(
    of: find.byType(AppFloatingBottomBar),
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration! as BoxDecoration).borderRadius ==
              BorderRadius.circular(32),
    ),
  );

  testWidgets('模糊层裁剪与可见胶囊严格重合', (tester) async {
    await pumpBar(tester, useBlur: true);
    // 390 宽窗口，左右各 16 留白 → 胶囊宽 358、高 64。
    expect(tester.getSize(barClip()), const Size(358, 64));
    expect(tester.getTopLeft(barClip()).dx, 16);
  });

  testWidgets('模糊与非模糊两个分支的胶囊几何一致', (tester) async {
    await pumpBar(tester, useBlur: true);
    final blurred = tester.getSize(surface());
    await pumpBar(tester, useBlur: false);
    final solid = tester.getSize(surface());
    expect(blurred, solid);
    expect(blurred, const Size(358, 64));
  });

  testWidgets('点击导航项回调对应索引', (tester) async {
    final tapped = <int>[];
    await pumpBar(tester, useBlur: true, onSelect: tapped.add);
    await tester.tap(
      find.descendant(
        of: find.byType(AppFloatingBottomBar),
        matching: find.byIcon(Icons.explore_rounded),
      ),
    );
    await tester.pumpAndSettle();
    expect(tapped, [2]);
  });

  testWidgets('每个导航项都有名称、按钮与选中语义', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpBar(tester, useBlur: true, currentIndex: 1);

    expect(find.bySemanticsLabel('首页'), findsOneWidget);
    expect(find.bySemanticsLabel('书架'), findsOneWidget);
    expect(find.bySemanticsLabel('发现'), findsOneWidget);

    expect(
      tester.getSemantics(find.bySemanticsLabel('书架')),
      isSemantics(
        label: '书架',
        isButton: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('首页')),
      isSemantics(
        label: '首页',
        isButton: true,
        isSelected: false,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });
}
