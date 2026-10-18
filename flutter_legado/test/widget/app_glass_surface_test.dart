import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:material_ui/material_ui.dart';

import 'package:flutter_legado/src/theme/app_glass_theme.dart';
import 'package:flutter_legado/src/theme/app_surface_material.dart';
import 'package:flutter_legado/src/widgets/app_glass_surface.dart';

void main() {
  testWidgets('背景切换保留前景State、尺寸与点击，未就绪不创建玻璃', (tester) async {
    const content = _Counter();
    Future<void> show(bool ready) => tester.pumpWidget(
      MaterialApp(
        home: AppGlassHost(
          available: ready,
          child: GlassTheme(
            data: GlassThemeData.simple(quality: GlassQuality.minimal),
            child: Center(
              child: AppGlassSurface(
                material: AppSurfaceMaterial.button(color: Colors.white),
                topRadius: 32,
                bottomRadius: 32,
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
    await show(false);
    await tester.pumpAndSettle();
    final state = tester.state(find.byType(_Counter));
    final size = tester.getSize(find.byType(AppGlassSurface));
    expect(find.byType(GlassContainer), findsNothing);
    await tester.tap(find.text('0'));
    await tester.pumpAndSettle();
    for (final ready in [true, false, true]) {
      await show(ready);
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(_Counter)), same(state));
      expect(tester.getSize(find.byType(AppGlassSurface)), size);
      expect(find.text('1'), findsOneWidget);
    }
    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets('表面遵循局部菜单亮度，保留上下不同圆角：$brightness', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            brightness: brightness == Brightness.light
                ? Brightness.dark
                : Brightness.light,
          ),
          home: AppGlassHost(
            available: true,
            child: GlassTheme(
              data: GlassThemeData.simple(quality: GlassQuality.minimal),
              child: Theme(
                data: ThemeData(brightness: brightness),
                child: Center(
                  child: AppGlassSurface(
                    material: AppSurfaceMaterial.button(color: Colors.white),
                    topRadius: 32,
                    bottomRadius: 0,
                    child: const SizedBox(width: 300, height: 100),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final glass = tester.widget<GlassContainer>(find.byType(GlassContainer));
      expect(
        GlassTheme.brightnessOf(tester.element(find.byType(GlassContainer))),
        brightness,
      );
      expect(
        glass.shape.toBorderRadius(),
        const BorderRadius.vertical(top: Radius.circular(32)),
      );
      expect(tester.getSize(find.byType(GlassContainer)), const Size(300, 100));
      expect(find.byType(GlassContainer), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

class _Counter extends StatefulWidget {
  const _Counter();
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int value = 0;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: SizedBox(
      width: 300,
      height: 100,
      child: TextButton(
        onPressed: () => setState(() => value++),
        child: Text('$value'),
      ),
    ),
  );
}
