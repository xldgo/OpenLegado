import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_legado/src/theme/app_glass_theme.dart';
import 'package:flutter_legado/src/theme/app_surface_material.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('玻璃遵循应用主题，覆盖相反系统亮度：$brightness', (tester) async {
      final systemBrightness = brightness == Brightness.light
          ? Brightness.dark
          : Brightness.light;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: MediaQuery(
            data: MediaQueryData(
              platformBrightness: systemBrightness,
              disableAnimations: true,
              highContrast: true,
            ),
            child: AppGlassHost(
              available: true,
              child: Builder(
                builder: (context) {
                  expect(GlassTheme.brightnessOf(context), brightness);
                  expect(
                    GlassThemeData.of(context).qualityFor(context),
                    GlassQuality.standard,
                  );
                  expect(AppGlassScope.availableOf(context), isTrue);
                  final accessibility = GlassAccessibilityData.of(context);
                  expect(accessibility.reduceMotion, isTrue);
                  expect(accessibility.reduceTransparency, isTrue);
                  return const Text('主题已装配');
                },
              ),
            ),
          ),
        ),
      );
      expect(find.text('主题已装配'), findsOneWidget);
    });
  }

  testWidgets('就绪状态变化通知组件，未装配宿主时默认关闭', (tester) async {
    bool? available;
    final child = Builder(
      builder: (context) {
        available = AppGlassScope.availableOf(context);
        return const SizedBox();
      },
    );
    await tester.pumpWidget(MaterialApp(home: child));
    expect(available, isFalse);
    for (final ready in [true, false]) {
      await tester.pumpWidget(
        MaterialApp(
          home: AppGlassHost(available: ready, child: child),
        ),
      );
      expect(available, ready);
    }
  });

  testWidgets('应用主题改变时更新玻璃亮度，保留内容状态', (tester) async {
    final brightness = ValueNotifier(Brightness.light);
    addTearDown(brightness.dispose);
    await tester.pumpWidget(
      ValueListenableBuilder(
        valueListenable: brightness,
        builder: (_, value, _) => MaterialApp(
          theme: ThemeData(brightness: value),
          home: const AppGlassHost(available: true, child: _StatefulContent()),
        ),
      ),
    );
    await tester.tap(find.text('0'));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
    brightness.value = Brightness.dark;
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(_StatefulContent));
    expect(GlassTheme.brightnessOf(context), Brightness.dark);
    expect(find.text('1'), findsOneWidget);
  });

  test('材质转换保留最终颜色和零模糊，不二次叠乘不透明度', () {
    for (final opacity in [0.0, 0.5, 1.0]) {
      final material = AppSurfaceMaterial.resolve(
        color: const Color(0x80FF0000),
        blurEnabled: true,
        backgroundOpacity: 0.2,
        blurTintOpacity: opacity,
        blurSigma: 0,
      );
      final glass = AppGlassStyle.resolve(material);
      expect(glass.glassColor, material.color);
      expect(glass.glassColor.a, closeTo((128 / 255) * opacity, 0.00001));
      expect(glass.blur, 0);
      expect(glass.bodyMode, GlassBodyMode.clear);
    }
  });
}

class _StatefulContent extends StatefulWidget {
  const _StatefulContent();

  @override
  State<_StatefulContent> createState() => _StatefulContentState();
}

class _StatefulContentState extends State<_StatefulContent> {
  int value = 0;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => setState(() => value++),
    child: Text('$value'),
  );
}
