import 'package:flutter/rendering.dart'
    show BackdropFilterLayer, ClipRectLayer, RenderSliver;
import 'package:flutter_legado/src/widgets/app_surface_backdrop.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_legado/src/domain/models/ui_settings.dart';
import 'package:flutter_legado/src/theme/app_surface_material.dart';
import 'package:flutter_legado/src/theme/app_theme.dart';
import 'package:flutter_legado/src/widgets/legado_app_bar.dart';
import 'package:flutter_legado/src/widgets/navigation/app_navigation_bars.dart';
import 'package:flutter_legado/src/widgets/top_bar_button.dart';
import 'package:flutter_legado/src/widgets/ui_settings_scope.dart';

void main() {
  const specs = [
    AppNavSpec(symbol: Icons.home, label: '首页'),
    AppNavSpec(symbol: Icons.book, label: '书架'),
  ];

  for (final brightness in Brightness.values) {
    for (final blurred in [false, true]) {
      for (final opacity in [0.0, 0.5, 1.0]) {
        testWidgets('上下栏仅调整背景：$brightness/模糊$blurred/$opacity', (tester) async {
          final settings = UiSettings(
            enableBlur: blurred,
            topBarBackgroundOpacity: opacity,
            bottomBarBackgroundOpacity: opacity,
            topBarBlurTintOpacity: opacity,
            bottomBarBlurTintOpacity: opacity,
          );
          final material = AppSurfaceMaterial.bottomBar(
            color: Colors.white,
            settings: settings,
          );
          var selected = -1;
          await tester.pumpWidget(
            UiSettingsScope(
              settings: settings,
              child: MaterialApp(
                theme: AppTheme.light,
                darkTheme: AppTheme.dark,
                themeMode: brightness == Brightness.dark
                    ? ThemeMode.dark
                    : ThemeMode.light,
                home: Scaffold(
                  appBar: const LegadoAppBar(
                    title: Text('标题'),
                    backgroundColor: Colors.black,
                    showBack: false,
                  ),
                  body: AppFloatingBottomBar(
                    specs: specs,
                    currentIndex: 0,
                    activeSkin: '',
                    material: material,
                    onSelect: (index) => selected = index,
                  ),
                  bottomNavigationBar: AppShortNavigationBar(
                    specs: specs,
                    currentIndex: 0,
                    activeSkin: '',
                    material: material,
                    labelBehavior:
                        NavigationDestinationLabelBehavior.alwaysShow,
                    onSelect: (index) => selected = index,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.widget<AppBar>(find.byType(AppBar)).backgroundColor!.a,
            opacity,
          );
          expect(
            tester
                .widget<NavigationBar>(find.byType(NavigationBar))
                .backgroundColor!
                .a,
            opacity,
          );
          expect(
            find.ancestor(
              of: find.byType(NavigationBar),
              matching: find.byType(Opacity),
            ),
            findsNothing,
          );
          final surface = tester
              .widgetList<Container>(
                find.descendant(
                  of: find.byType(AppFloatingBottomBar),
                  matching: find.byType(Container),
                ),
              )
              .firstWhere(
                (widget) =>
                    widget.decoration is BoxDecoration &&
                    (widget.decoration! as BoxDecoration).color != null,
              );
          expect((surface.decoration! as BoxDecoration).color!.a, opacity);
          expect(
            find.byType(BackdropFilter),
            blurred ? findsNWidgets(3) : findsNothing,
          );
          await tester.tap(
            find.descendant(
              of: find.byType(NavigationBar),
              matching: find.text('书架'),
            ),
          );
          await tester.pump();
          expect(selected, 1);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  for (final large in [false, true]) {
    testWidgets('可折叠头部材质不改变大标题/滚动几何：$large', (tester) async {
      var selected = 0;
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      final body = CustomScrollView(
        controller: scroll,
        slivers: [
          LegadoTabRootHeaderSliver(
            title: const Text('书架'),
            large: large,
            actions: [
              IconButton(
                tooltip: '操作',
                onPressed: () => selected++,
                icon: const Icon(Icons.more_horiz),
              ),
            ],
          ),
          SliverList.builder(
            itemCount: 50,
            itemBuilder: (context, index) =>
                SizedBox(height: 50, child: Text('正文$index')),
          ),
        ],
      );
      Future<void> show(UiSettings settings) async {
        await tester.pumpWidget(
          UiSettingsScope(
            settings: settings,
            child: MaterialApp(
              theme: AppTheme.light,
              home: Scaffold(body: body),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await show(
        const UiSettings(enableBlur: true, topBarBackgroundOpacity: 0),
      );
      final bar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
      expect(bar.backgroundColor!.a, closeTo(0.73, 1e-6));
      final render = tester.renderObject<RenderSliver>(
        find.byType(AppSliverSurfaceBackdrop),
      );
      final expanded = render.geometry!.paintExtent;
      void checkClip() {
        final filter = tester.layers.whereType<BackdropFilterLayer>().single;
        expect(filter.parent, isA<ClipRectLayer>());
        expect(
          (filter.parent! as ClipRectLayer).clipRect!.height,
          render.geometry!.paintExtent,
        );
      }

      checkClip();
      await tester.tap(find.byTooltip('操作'));
      expect(selected, 1);
      scroll.jumpTo(250);
      await tester.pumpAndSettle();
      expect(render.geometry!.paintExtent, lessThanOrEqualTo(expanded));
      if (large) expect(render.geometry!.paintExtent, lessThan(expanded));
      checkClip();
      final collapsed = render.geometry!.paintExtent;
      await show(const UiSettings(topBarBackgroundOpacity: 0.5));
      expect(tester.layers.whereType<BackdropFilterLayer>(), isEmpty);
      expect(
        tester
            .widget<SliverAppBar>(find.byType(SliverAppBar))
            .backgroundColor!
            .a,
        0.5,
      );
      expect(render.geometry!.paintExtent, collapsed);
      expect(scroll.offset, 250);
      expect(find.text('书架'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('共用大标题容器复用材质，切换普通头部时保持内容', (tester) async {
    const child = MaterialApp(
      home: Scaffold(
        body: LegadoLargeTitleScroll(
          title: Text('我的'),
          body: SizedBox.expand(child: Text('内容')),
        ),
      ),
    );
    await tester.pumpWidget(
      const UiSettingsScope(
        settings: UiSettings(enableBlur: true),
        child: child,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.layers.whereType<BackdropFilterLayer>(), hasLength(1));
    expect(
      tester.widget<SliverAppBar>(find.byType(SliverAppBar)).backgroundColor!.a,
      closeTo(0.73, 1e-6),
    );
    await tester.pumpWidget(
      const UiSettingsScope(
        settings: UiSettings(
          useFlexibleTopAppBar: false,
          topBarBackgroundOpacity: 0,
        ),
        child: child,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.layers.whereType<BackdropFilterLayer>(), isEmpty);
    expect(
      tester.widget<SliverAppBar>(find.byType(SliverAppBar)).backgroundColor!.a,
      0,
    );
    expect(find.text('内容'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('独立按钮和合并胶囊使用同一材质底色', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              TopBarButton(
                icon: Icons.search,
                tooltip: '独立',
                onPressed: () {},
                style: TopBarButtonStyle.glass,
              ),
              TopBarActionStyler(
                style: TopBarButtonStyle.glass,
                merge: false,
                actions: [
                  IconButton(icon: const Icon(Icons.book), onPressed: () {}),
                ],
              ),
              TopBarActionStyler(
                style: TopBarButtonStyle.glass,
                merge: true,
                actions: [
                  IconButton(icon: const Icon(Icons.menu), onPressed: () {}),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    final surfaces = tester
        .widgetList<Container>(find.byType(Container))
        .where(
          (widget) =>
              widget.decoration is BoxDecoration &&
              (widget.decoration! as BoxDecoration).color != null,
        )
        .map((widget) => (widget.decoration! as BoxDecoration).color!)
        .toList();
    expect(surfaces, hasLength(3));
    expect(surfaces.toSet(), hasLength(1));
    expect(surfaces.first.a, 0.5);
  });
}
