import 'dart:ui' show SemanticsAction;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:material_ui/material_ui.dart';

import 'package:flutter_legado/src/domain/models/ui_settings.dart';
import 'package:flutter_legado/src/theme/app_glass_theme.dart';
import 'package:flutter_legado/src/theme/app_surface_material.dart';
import 'package:flutter_legado/src/widgets/navigation/app_navigation_bars.dart';

void main() {
  const specs = [
    AppNavSpec(symbol: Icons.home_rounded, label: '首页'),
    AppNavSpec(symbol: Icons.menu_book_rounded, label: '书架'),
    AppNavSpec(symbol: Icons.explore_rounded, label: '发现'),
  ];

  Future<void> show(
    WidgetTester tester, {
    bool enabled = true,
    bool ready = true,
    bool reduced = false,
    Brightness brightness = Brightness.light,
    TextDirection direction = TextDirection.ltr,
    List<AppNavSpec> items = specs,
    String activeSkin = '',
    int selected = 0,
    ValueChanged<int>? onSelect,
    bool showLabels = true,
    double textScale = 1,
    double bottomInset = 0,
    Size window = const Size(390, 844),
  }) async {
    tester.view.physicalSize = window;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: MediaQuery(
          data: MediaQueryData(
            padding: EdgeInsets.only(bottom: bottomInset),
            viewPadding: EdgeInsets.only(bottom: bottomInset),
            disableAnimations: reduced,
            textScaler: TextScaler.linear(textScale),
          ),
          child: Directionality(
            textDirection: direction,
            child: AppGlassHost(
              available: ready,
              // 控制器、命中与语义走真实库组件；GPU光学另行在设备验收。
              child: GlassTheme(
                data: GlassThemeData.simple(
                  quality: GlassQuality.minimal,
                  brightness: brightness,
                ),
                child: StatefulBuilder(
                  builder: (context, setState) => Scaffold(
                    body: const SizedBox.expand(),
                    bottomNavigationBar: AppFloatingBottomBar(
                      specs: items,
                      currentIndex: selected,
                      activeSkin: activeSkin,
                      useLiquidGlass: enabled,
                      showLabels: showLabels,
                      onSelect: (index) {
                        onSelect?.call(index);
                        setState(() => selected = index);
                      },
                      material: AppSurfaceMaterial.bottomBar(
                        color: Colors.white,
                        settings: const UiSettings(),
                        liquidGlass: enabled && ready,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Offset tabCenter(WidgetTester tester, int physicalIndex, int count) {
    final rect = tester.getRect(find.byType(GlassTabBar));
    return Offset(
      rect.left + rect.width * (physicalIndex + 0.5) / count,
      rect.center.dy,
    );
  }

  for (final inset in [0.0, 24.0, 34.0]) {
    testWidgets('玻璃胶囊底部安全区不叠加悬浮留白：$inset', (tester) async {
      await show(tester, bottomInset: inset);
      final bar = tester.getRect(find.byType(GlassTabBar));
      expect(844 - bar.bottom, inset < 12 ? 12 : inset);
      final icon = find.byIcon(Icons.home_rounded).first;
      final label = find.text('首页').first;
      expect(tester.getSize(icon), const Size(28, 28));
      expect(tester.getRect(label).top, tester.getRect(icon).bottom);
      expect(tester.takeException(), isNull);
    });
  }

  for (final flags in [(true, true), (false, true), (true, false)]) {
    testWidgets('胶囊默认显示全部文字，隐藏时保留名称语义：$flags', (tester) async {
      final calls = <int>[];
      await show(
        tester,
        enabled: flags.$1,
        ready: flags.$2,
        onSelect: calls.add,
      );
      for (final name in ['首页', '书架', '发现']) {
        expect(find.text(name), findsWidgets);
      }
      final discover = find.descendant(
        of: find.byType(AppFloatingBottomBar),
        matching: find.bySemanticsLabel('发现'),
      );
      await tester.tap(discover);
      await tester.pumpAndSettle();
      expect(calls.last, 2);
      for (final name in ['首页', '书架', '发现']) {
        expect(find.text(name), findsWidgets);
      }
      await show(
        tester,
        enabled: flags.$1,
        ready: flags.$2,
        showLabels: false,
        onSelect: calls.add,
      );
      for (final name in ['首页', '书架', '发现']) {
        expect(find.text(name), findsNothing);
        expect(find.bySemanticsLabel(name), findsOneWidget);
      }
      await tester.tap(find.bySemanticsLabel('书架'));
      await tester.pumpAndSettle();
      expect(calls.last, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('窄屏大字五项胶囊文字不溢出：$flags', (tester) async {
      await show(
        tester,
        enabled: flags.$1,
        ready: flags.$2,
        window: const Size(320, 640),
        textScale: 2,
        items: const [
          ...specs,
          AppNavSpec(symbol: Icons.rss_feed, label: '订阅'),
          AppNavSpec(symbol: Icons.person, label: '我的'),
        ],
      );
      for (final name in ['首页', '书架', '发现', '订阅', '我的']) {
        final text = find.text(name).first;
        expect(text, findsOneWidget);
        expect(tester.getSize(text).height, greaterThan(0));
      }
      expect(
        tester.getSize(find.byType(AppFloatingBottomBar)).height,
        greaterThan(76),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('关闭设置或资源未就绪时使用普通材质', (tester) async {
    for (final flags in [(false, true), (true, false)]) {
      await show(tester, enabled: flags.$1, ready: flags.$2);
      expect(find.byType(GlassTabBar), findsNothing);
      expect(find.bySemanticsLabel('书架'), findsOneWidget);
      expect(tester.getSize(find.byType(AppFloatingBottomBar)).height, 76);
      expect(tester.takeException(), isNull);
    }
  });

  for (final brightness in Brightness.values) {
    testWidgets('液态导航保留胶囊几何、重复点击与独立选中语义：$brightness', (tester) async {
      final semantics = tester.ensureSemantics();
      final calls = <int>[];
      await show(
        tester,
        brightness: brightness,
        selected: 1,
        onSelect: calls.add,
      );
      final rect = tester.getRect(find.byType(GlassTabBar));
      expect(rect.width, 358);
      expect(rect.height, 64);
      expect(rect.left, 16);
      expect(find.byType(AnimatedScale), findsNothing);
      await tester.tapAt(tabCenter(tester, 1, 3));
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tapAt(tabCenter(tester, 1, 3));
      await tester.pumpAndSettle();
      expect(calls, [1, 1]);
      for (final name in ['首页', '书架', '发现']) {
        final finder = find.bySemanticsLabel(name);
        expect(finder, findsOneWidget);
        final data = tester.getSemantics(finder).getSemanticsData();
        expect(data.flagsCollection.isButton, isTrue);
        expect(data.flagsCollection.isSelected.toBoolOrNull(), name == '书架');
        expect(data.hasAction(SemanticsAction.tap), isTrue);
      }
      final discover = tester.getSemantics(find.bySemanticsLabel('发现'));
      discover.owner!.performAction(discover.id, SemanticsAction.tap);
      await tester.pumpAndSettle();
      expect(calls.last, 2);
      expect(
        tester.widget<GlassTabBar>(find.byType(GlassTabBar)).selectedIndex,
        2,
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }

  testWidgets('键盘激活与拖动选择保持可用', (tester) async {
    final calls = <int>[];
    await show(tester, onSelect: calls.add);
    final barContext = tester.element(find.byType(GlassTabBar));
    final focus = FocusScope.of(barContext);
    focus.nextFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(calls, isNotEmpty);
    await tester.dragFrom(tabCenter(tester, 0, 3), const Offset(235, 0));
    await tester.pumpAndSettle();
    expect(calls.last, 2);
    expect(
      tester.widget<GlassTabBar>(find.byType(GlassTabBar)).selectedIndex,
      2,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('皮肤缺图时仍显示图标并能选择，保留各状态槽位', (tester) async {
    final calls = <int>[];
    await show(
      tester,
      activeSkin: '../无效皮肤',
      items: [
        for (var i = 0; i < specs.length; i++)
          AppNavSpec(
            symbol: specs[i].symbol,
            label: specs[i].label,
            skinSlot: ['home_page', 'bookshelf', 'home'][i],
          ),
      ],
      onSelect: calls.add,
    );
    expect(find.byType(SkinNavIcon), findsWidgets);
    expect(find.byIcon(Icons.menu_book_rounded), findsWidgets);
    final bar = tester.widget<GlassTabBar>(find.byType(GlassTabBar));
    final normal = bar.tabs[1].icon! as SkinNavIcon;
    final selected = bar.tabs[1].activeIcon! as SkinNavIcon;
    expect(normal.slot, 'bookshelf');
    expect(normal.selected, isFalse);
    expect(selected.slot, 'bookshelf');
    expect(selected.selected, isTrue);
    await tester.tapAt(tabCenter(tester, 1, 3));
    await tester.pumpAndSettle();
    expect(calls, [1]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('减少动态效果时取消放大，RTL点击映射到逻辑页签', (tester) async {
    final calls = <int>[];
    await show(
      tester,
      reduced: true,
      direction: TextDirection.rtl,
      onSelect: calls.add,
    );
    expect(
      tester.widget<GlassTabBar>(find.byType(GlassTabBar)).magnification,
      1,
    );
    await tester.tapAt(tabCenter(tester, 0, 3));
    await tester.pumpAndSettle();
    expect(calls, [2]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('快速点击、取消与页签数量变化后仍能选择', (tester) async {
    final calls = <int>[];
    await show(tester, onSelect: calls.add);
    await tester.tapAt(tabCenter(tester, 2, 3));
    await tester.pump(const Duration(milliseconds: 10));
    await tester.tapAt(tabCenter(tester, 0, 3));
    await tester.pumpAndSettle();
    expect(calls, [2, 0]);
    final gesture = await tester.startGesture(tabCenter(tester, 1, 3));
    await gesture.cancel();
    await tester.pumpAndSettle();
    await show(tester, items: specs.take(2).toList(), onSelect: calls.add);
    await tester.tapAt(tabCenter(tester, 1, 2));
    await tester.pumpAndSettle();
    expect(calls.last, 1);
    expect(tester.takeException(), isNull);
  });
}
