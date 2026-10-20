import 'dart:ui' show SemanticsAction;

import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart' show SemanticsNode;
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:material_ui/material_ui.dart';

import 'package:flutter_legado/src/domain/models/ui_settings.dart';
import 'package:flutter_legado/src/theme/app_glass_theme.dart';
import 'package:flutter_legado/src/theme/app_surface_material.dart';
import 'package:flutter_legado/src/widgets/app_menu.dart';
import 'package:flutter_legado/src/widgets/legado_app_bar.dart';
import 'package:flutter_legado/src/widgets/top_bar_button.dart';
import 'package:flutter_legado/src/widgets/ui_settings_scope.dart';

/// 验证真实材质组件的装配与交互；standard着色器的视觉效果由设备另行验收。— Codex + UI
Widget _host(
  Widget child, {
  bool ready = true,
  bool reduced = false,
  Brightness brightness = Brightness.light,
  UiSettings settings = const UiSettings(),
  bool page = false,
}) => MaterialApp(
  theme: ThemeData(brightness: brightness),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: AppGlassHost(
      available: ready,
      child: GlassTheme(
        data: GlassThemeData.simple(
          brightness: brightness,
          quality: GlassQuality.minimal,
        ),
        child: UiSettingsScope(
          settings: settings,
          child: page ? child : Scaffold(body: Center(child: child)),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('Plain档即使开启合并也保留独立按钮与点击区域', (tester) async {
    await tester.pumpWidget(
      _host(
        TopBarActionStyler(
          style: TopBarButtonStyle.plain,
          merge: true,
          actions: [
            IconButton(onPressed: () {}, icon: const Icon(Icons.search)),
            IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert)),
          ],
        ),
      ),
    );
    expect(find.byType(GlassContainer), findsNothing);
    expect(tester.getSize(find.byType(TopBarActionStyler)), const Size(96, 48));
    expect(tester.takeException(), isNull);
  });

  for (final style in [
    TopBarButtonStyle.outlined,
    TopBarButtonStyle.glass,
    TopBarButtonStyle.liquidGlass,
  ]) {
    for (final height in [56.0, 64.0]) {
      testWidgets('真实顶栏仅合并右侧，保持按钮视觉高度：$style/$height', (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          _host(
            Scaffold(
              appBar: LegadoAppBar(
                title: const Text('标题'),
                showBack: true,
                toolbarHeight: height,
                actions: [
                  IconButton(
                    tooltip: '查找',
                    onPressed: () => taps++,
                    icon: const Icon(Icons.search),
                  ),
                  IconButton(
                    tooltip: '操作',
                    onPressed: () {},
                    icon: const Icon(Icons.more_vert),
                  ),
                ],
              ),
            ),
            page: true,
            settings: UiSettings(
              topBarButtonStyle: style,
              mergeTopBarActions: true,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final capsules = find.byWidgetPredicate(
          (widget) => style == TopBarButtonStyle.liquidGlass
              ? widget is GlassContainer &&
                    widget.shape is LiquidRoundedRectangle
              : widget is Container &&
                    widget.decoration is BoxDecoration &&
                    (widget.decoration! as BoxDecoration).borderRadius ==
                        BorderRadius.circular(20),
        );
        expect(capsules, findsOneWidget);
        expect(tester.getSize(capsules).height, 36);
        final leading = tester.widget<AppBar>(find.byType(AppBar)).leading!;
        expect(tester.getSize(find.byWidget(leading)).width, 56);
        await tester.tap(find.byTooltip('查找'));
        expect(taps, 1);
        if (style == TopBarButtonStyle.liquidGlass) {
          final surface = find.byWidgetPredicate(
            (widget) =>
                widget is GlassContainer &&
                widget.shape is LiquidRoundedRectangle,
          );
          expect(tester.getSize(surface), const Size(89, 36));
        }
      });
    }
  }

  testWidgets('单动作合并背景退化为36dp圆形，保持48dp热区', (tester) async {
    await tester.pumpWidget(
      _host(
        Scaffold(
          appBar: LegadoAppBar(
            title: const Text('标题'),
            showBack: false,
            toolbarHeight: 64,
            actions: [
              IconButton(onPressed: () {}, icon: const Icon(Icons.search)),
            ],
          ),
        ),
        page: true,
        settings: const UiSettings(
          topBarButtonStyle: TopBarButtonStyle.liquidGlass,
          mergeTopBarActions: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(GlassContainer)), const Size(36, 36));
    expect(tester.getSize(find.byType(IconButton)), const Size(48, 48));
    expect(tester.takeException(), isNull);
  });

  for (final merge in [false, true]) {
    testWidgets('液态按钮保留48dp热区与菜单，仅合并时共用一层：$merge', (tester) async {
      var taps = 0;
      String? selected;
      await tester.pumpWidget(
        _host(
          TopBarActionStyler(
            style: TopBarButtonStyle.liquidGlass,
            merge: merge,
            actions: [
              IconButton(
                tooltip: '查找',
                icon: const Icon(Icons.search),
                onPressed: () => taps++,
              ),
              AppMenuButton<String>(
                tooltip: '菜单',
                itemBuilder: (_) => const [
                  AppMenuItem(value: '选项', child: Text('菜单选项')),
                ],
                onSelected: (value) => selected = value,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GlassContainer), findsNWidgets(merge ? 1 : 2));
      final buttons = find.byType(IconButton);
      for (var i = 0; i < 2; i++) {
        expect(tester.getSize(buttons.at(i)), const Size(48, 48));
      }
      if (!merge) {
        expect(
          tester.getSize(find.byType(GlassContainer).first),
          const Size(36, 36),
        );
      } else {
        expect(tester.getSize(find.byType(GlassContainer)), const Size(89, 36));
      }
      // 触点位于视觉圆之外、48dp热区之内，材质不能截断此处输入。
      await tester.tapAt(
        tester.getTopLeft(buttons.first) + const Offset(2, 24),
      );
      expect(taps, 1);
      await tester.tap(find.byTooltip('菜单'));
      await tester.pumpAndSettle();
      expect(find.text('菜单选项'), findsOneWidget);
      await tester.tap(find.text('菜单选项'));
      await tester.pumpAndSettle();
      expect(selected, '选项');
      expect(find.text('菜单选项'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('预热状态变化保留菜单归属与几何：$merge', (tester) async {
      final action = TopBarActionStyler(
        style: TopBarButtonStyle.liquidGlass,
        merge: merge,
        actions: [
          AppMenuButton<String>(
            tooltip: '菜单',
            itemBuilder: (_) => const [
              AppMenuItem(value: '选项', child: Text('菜单选项')),
            ],
            onSelected: (_) {},
          ),
        ],
      );
      await tester.pumpWidget(_host(action, ready: false));
      await tester.pumpAndSettle();
      expect(find.byType(GlassContainer), findsNothing);
      final size = tester.getSize(find.byType(TopBarActionStyler));
      final position = tester.getTopLeft(find.byType(IconButton));
      await tester.tap(find.byTooltip('菜单'));
      await tester.pumpAndSettle();
      expect(find.text('菜单选项'), findsOneWidget);
      final anchor = tester.state(find.byType(AppMenuAnchor<String>));
      await tester.pumpWidget(_host(action));
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(AppMenuAnchor<String>)), same(anchor));
      expect(find.text('菜单选项'), findsOneWidget);
      expect(find.byType(GlassContainer), findsOneWidget);
      expect(tester.getSize(find.byType(TopBarActionStyler)), size);
      expect(tester.getTopLeft(find.byType(IconButton).first), position);
      await tester.pumpWidget(_host(action, ready: false));
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(AppMenuAnchor<String>)), same(anchor));
      expect(find.text('菜单选项'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('菜单选项'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final brightness in Brightness.values) {
    testWidgets('独立按钮材质跟随主题，前景不随底色变淡：$brightness', (tester) async {
      var taps = 0;
      final button = TopBarButton(
        icon: Icons.search,
        tooltip: '查找',
        style: TopBarButtonStyle.liquidGlass,
        onPressed: () => taps++,
      );
      await tester.pumpWidget(_host(button, brightness: brightness));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(TopBarButton));
      final cs = Theme.of(context).colorScheme;
      final glass = tester.widget<GlassContainer>(find.byType(GlassContainer));
      expect(
        glass.settings!.glassColor,
        AppSurfaceMaterial.buttonColor(cs.surfaceContainerHighest),
      );
      expect(glass.settings!.blur, 8);
      expect(GlassTheme.brightnessOf(context), brightness);
      expect(
        tester.widget<IconButton>(find.byType(IconButton)).color,
        cs.onSurface,
      );
      await tester.tap(find.byTooltip('查找'));
      expect(taps, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('禁用、键盘与无障碍沿用原按钮，不增加重复入口', (tester) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      _host(
        TopBarActionStyler(
          style: TopBarButtonStyle.liquidGlass,
          merge: true,
          actions: [
            IconButton(
              tooltip: '查找',
              focusNode: focus,
              icon: const Icon(Icons.search),
              onPressed: () => taps++,
            ),
            const IconButton(
              tooltip: '禁用',
              icon: Icon(Icons.delete),
              onPressed: null,
            ),
          ],
        ),
        reduced: true,
      ),
    );
    await tester.pumpAndSettle();
    final buttonNodes = <SemanticsNode>[];
    void collect(SemanticsNode node) {
      if (node.flagsCollection.isButton) buttonNodes.add(node);
      node.visitChildren((child) {
        collect(child);
        return true;
      });
    }

    collect(
      tester
          .binding
          .renderViews
          .single
          .owner!
          .semanticsOwner!
          .rootSemanticsNode!,
    );
    expect(buttonNodes, hasLength(2));
    expect(
      tester
          .getSemantics(find.byTooltip('查找'))
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isTrue,
    );
    expect(
      tester
          .getSemantics(find.byTooltip('禁用'))
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isFalse,
    );
    await tester.tap(find.byTooltip('禁用'));
    expect(taps, 0);
    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(find.byType(AnimatedScale), findsNothing);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('自定义文字和菜单入口不被替换或压缩', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        TopBarActionStyler(
          style: TopBarButtonStyle.liquidGlass,
          merge: false,
          actions: [
            TextButton(onPressed: () => taps++, child: const Text('完成')),
            AppMenuButton<String>(
              child: const SizedBox(width: 80, child: Text('自定义入口')),
              itemBuilder: (_) => const [
                AppMenuItem(value: '选项', child: Text('菜单选项')),
              ],
              onSelected: (_) {},
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(GlassContainer), findsNothing);
    expect(tester.getSize(find.byType(AppMenuButton<String>)).width, 80);
    await tester.tap(find.text('完成'));
    expect(taps, 1);
    await tester.tap(find.text('自定义入口'));
    await tester.pumpAndSettle();
    expect(find.text('菜单选项'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('全局样式接入顶栏返回与动作，页面显式样式优先', (tester) async {
    final page = Scaffold(
      appBar: LegadoAppBar(
        title: const Text('标题'),
        showBack: true,
        actions: [
          IconButton(
            tooltip: '查找',
            onPressed: () {},
            icon: const Icon(Icons.search),
          ),
        ],
      ),
    );
    await tester.pumpWidget(
      _host(
        page,
        page: true,
        settings: const UiSettings(
          topBarButtonStyle: TopBarButtonStyle.liquidGlass,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(GlassContainer), findsNWidgets(2));
    await tester.pumpWidget(
      _host(
        Scaffold(
          appBar: LegadoAppBar(
            title: const Text('标题'),
            showBack: true,
            actionsStyle: TopBarButtonStyle.plain,
            actions: [
              IconButton(onPressed: () {}, icon: const Icon(Icons.search)),
            ],
          ),
        ),
        page: true,
        settings: const UiSettings(
          topBarButtonStyle: TopBarButtonStyle.liquidGlass,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(GlassContainer), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
