import 'package:flutter_legado/src/domain/models/reader_menu_theme_settings.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_legado/src/domain/models/ui_settings.dart';
import 'package:flutter_legado/src/theme/app_theme.dart';
import 'package:flutter_legado/src/features/reader/widgets/reader_menu_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const paper = Color(0xFFF5EEDB);
  const ui = UiSettings();

  ThemeData resolve(
    ReaderMenuThemeSettings config, {
    ThemeData? app,
    Color background = paper,
    UiSettings settings = ui,
  }) => resolveReaderMenuTheme(
    appTheme: app ?? AppTheme.light,
    readingBackground: background,
    config: config,
    ui: settings,
  );

  test('跟随应用直接保留主题对象与纯黑表面', () {
    final app = AppTheme.dark.copyWith(
      colorScheme: AppTheme.dark.colorScheme.copyWith(surface: Colors.black),
    );
    expect(
      identical(resolve(ReaderMenuThemeSettings(), app: app), app),
      isTrue,
    );
  });

  test('正文背景生成完整颜色角色，明暗仍跟随应用', () {
    final config = ReaderMenuThemeSettings(mode: 1);
    final light = resolve(config);
    final green = resolve(config, background: const Color(0xFFCCE8CF));
    final dark = resolve(config, app: AppTheme.dark, background: Colors.white);
    expect(light.colorScheme.primary, isNot(green.colorScheme.primary));
    expect(light.colorScheme.surfaceContainerHigh, isNot(paper));
    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
    expect(
      dark.colorScheme.surfaceContainerHigh.computeLuminance(),
      lessThan(0.2),
    );
    expect(dark.colorScheme.onSurface.computeLuminance(), greaterThan(0.5));
  });

  test('独立阅读夜间使用菜单夜间配色，应用主题保持亮色', () {
    final app = AppTheme.light;
    final config = ReaderMenuThemeSettings(
      mode: 2,
      colorMode: 1,
      backgroundColor: 0xFFF5EEDB,
      backgroundColorNight: 0xFF232323,
      accentColorNight: 0xFF88C16F,
    );
    final theme = resolveReaderMenuTheme(
      appTheme: app,
      readingBackground: const Color(0xFF3C3F43),
      config: config,
      ui: ui,
      readingBrightness: Brightness.dark,
    );
    expect(app.brightness, Brightness.light);
    expect(theme.brightness, Brightness.dark);
    expect(theme.colorScheme.surfaceContainerHigh, const Color(0xFF232323));
    expect(theme.colorScheme.primary, const Color(0xFF88C16F));
  });

  test('组件主题同步局部色板，保留应用字阶', () {
    final app = AppTheme.light;
    final theme = resolve(ReaderMenuThemeSettings(mode: 1), app: app);
    final colors = theme.colorScheme;
    expect(theme.textTheme.titleMedium?.color, colors.onSurface);
    expect(
      theme.textTheme.titleMedium?.fontSize,
      app.textTheme.titleMedium?.fontSize,
    );
    expect(theme.iconButtonTheme.style?.foregroundColor, isNull);
    expect(theme.chipTheme.backgroundColor, isNull);
    expect(theme.chipTheme.labelStyle, isNull);
    expect(
      theme.menuTheme.style?.backgroundColor?.resolve({}),
      colors.surfaceContainerLow,
    );
    expect(theme.sliderTheme.activeTrackColor, isNull);
    expect(theme.sliderTheme.inactiveTrackColor, isNull);
    expect(theme.sliderTheme.thumbColor, isNull);
  });

  test('自定义实色分别选择日夜值并计算主色上的前景', () {
    final config = ReaderMenuThemeSettings(
      mode: 2,
      colorMode: 1,
      accentColor: 0xFFFFFFFF,
      accentColorNight: 0xFF123456,
      backgroundColor: 0xFFF0E0D0,
      backgroundColorNight: 0xFF121212,
      containerColor: 0xFFE0D0C0,
      containerColorNight: 0xFF242424,
    );
    final light = resolve(config).colorScheme;
    final dark = resolve(config, app: AppTheme.dark).colorScheme;
    expect(light.primary, Colors.white);
    expect(light.onPrimary, Colors.black);
    expect(light.surfaceContainerHigh, const Color(0xFFF0E0D0));
    expect(light.surfaceContainerLow, const Color(0xFFE0D0C0));
    expect(dark.primary, const Color(0xFF123456));
    expect(dark.onPrimary, Colors.white);
    expect(dark.surfaceContainerHigh, const Color(0xFF121212));
    expect(dark.surfaceContainerLow, const Color(0xFF242424));
  });

  test('种子生成模式忽略手动背景；自定义默认容器回退菜单背景', () {
    final config = ReaderMenuThemeSettings(
      mode: 2,
      accentColor: 0xFF6750A4,
      backgroundColor: 0xFFFF0000,
    );
    expect(
      resolve(config).colorScheme.surfaceContainerHigh,
      isNot(const Color(0xFFFF0000)),
    );
    final manual = ReaderMenuThemeSettings(
      mode: 2,
      colorMode: 1,
      accentColor: 0xFF6750A4,
      backgroundColor: 0xFFFF0000,
    );
    expect(
      resolve(manual).colorScheme.surfaceContainerLow,
      const Color(0xFFFF0000),
    );
    final fallback = ReaderMenuThemeSettings(
      mode: 2,
      colorMode: 1,
      accentColor: 0xFF6750A4,
    );
    expect(resolve(fallback).colorScheme.surfaceContainerHigh, paper);
    expect(resolve(fallback).colorScheme.surfaceContainerLow, paper);
  });

  test('菜单可继承或独立选择配色风格与对比度', () {
    final config = ReaderMenuThemeSettings(mode: 1);
    final inherited = resolve(
      config,
      settings: const UiSettings(
        themeStyle: 'monochrome',
        themeContrastLevel: '0.5',
      ),
    );
    final explicit = resolve(
      ReaderMenuThemeSettings(mode: 1, paletteStyle: 'monochrome'),
      settings: const UiSettings(themeContrastLevel: '0.5'),
    );
    expect(inherited.colorScheme, explicit.colorScheme);
    final standard = resolve(
      ReaderMenuThemeSettings(mode: 1, paletteStyle: 'monochrome'),
    );
    expect(standard.colorScheme.outline, isNot(explicit.colorScheme.outline));
  });
}
