import 'package:flutter_legado/src/data/repositories/preferences_reader_config_repository.dart';
import 'package:flutter_legado/src/models/reader_advanced_config.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/providers/ui_settings/ui_settings_notifier.dart';
import 'package:flutter_legado/src/theme/app_theme.dart';
import 'package:flutter_legado/src/widgets/reader/reader_menu_theme.dart';

void main() {
  late PreferencesReaderConfigRepository repository;
  setUp(() => repository = PreferencesReaderConfigRepository());
  TestWidgetsFlutterBinding.ensureInitialized();
  const paper = Color(0xFFF5EEDB);
  const ui = UiSettingsState();

  ThemeData resolve(
    ReaderAdvancedConfig config, {
    ThemeData? app,
    Color background = paper,
    UiSettingsState settings = ui,
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
    expect(identical(resolve(ReaderAdvancedConfig(), app: app), app), isTrue);
  });

  test('正文背景生成完整颜色角色，明暗仍跟随应用', () {
    final config = ReaderAdvancedConfig(readBarStyle: 1);
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

  test('组件主题同步局部色板，保留应用字阶', () {
    final app = AppTheme.light;
    final theme = resolve(ReaderAdvancedConfig(readBarStyle: 1), app: app);
    final colors = theme.colorScheme;
    expect(theme.textTheme.titleMedium?.color, colors.onSurface);
    expect(
      theme.textTheme.titleMedium?.fontSize,
      app.textTheme.titleMedium?.fontSize,
    );
    expect(
      theme.iconButtonTheme.style?.foregroundColor?.resolve({}),
      colors.onSurfaceVariant,
    );
    expect(theme.chipTheme.backgroundColor, colors.surfaceContainerLow);
    expect(
      theme.menuTheme.style?.backgroundColor?.resolve({}),
      colors.surfaceContainerLow,
    );
    expect(theme.sliderTheme.activeTrackColor, colors.primary);
  });

  test('自定义实色分别选择日夜值并计算主色上的前景', () {
    final config = ReaderAdvancedConfig(
      readBarStyle: 2,
      readMenuColorMode: 1,
      readMenuAccentColor: 0xFFFFFFFF,
      readMenuAccentColorNight: 0xFF123456,
      readMenuBgColor: 0xFFF0E0D0,
      readMenuBgColorNight: 0xFF121212,
      readMenuContainerColor: 0xFFE0D0C0,
      readMenuContainerColorNight: 0xFF242424,
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
    final config = ReaderAdvancedConfig(
      readBarStyle: 2,
      readMenuAccentColor: 0xFF6750A4,
      readMenuBgColor: 0xFFFF0000,
    );
    expect(
      resolve(config).colorScheme.surfaceContainerHigh,
      isNot(const Color(0xFFFF0000)),
    );
    config.readMenuColorMode = 1;
    expect(
      resolve(config).colorScheme.surfaceContainerLow,
      const Color(0xFFFF0000),
    );
    config.readMenuBgColor = 0;
    expect(resolve(config).colorScheme.surfaceContainerHigh, paper);
    expect(resolve(config).colorScheme.surfaceContainerLow, paper);
  });

  test('菜单可继承或独立选择配色风格与对比度', () {
    final config = ReaderAdvancedConfig(readBarStyle: 1);
    final inherited = resolve(
      config,
      settings: const UiSettingsState(
        themeStyle: 'monochrome',
        themeContrastLevel: '0.5',
      ),
    );
    config.readMenuPaletteStyle = 'monochrome';
    final explicit = resolve(
      config,
      settings: const UiSettingsState(themeContrastLevel: '0.5'),
    );
    expect(inherited.colorScheme, explicit.colorScheme);
    final standard = resolve(config);
    expect(standard.colorScheme.outline, isNot(explicit.colorScheme.outline));
  });

  test('旧开关迁移为背景模式，新模式优先；复制与保存保留颜色', () async {
    SharedPreferences.setMockInitialValues({'readBarStyleFollowPage': true});
    expect((await repository.load()).readBarStyle, 1);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('readBarStyle', 2);
    final config = await repository.load();
    expect(config.readBarStyle, 2);
    config.readMenuPaletteStyle = 'vibrant';
    config.readMenuColorMode = 1;
    config.readMenuAccentColor = 0xFF123456;
    config.readMenuAccentColorNight = 0xFFABCDEF;
    config.readMenuBgColor = 0xFFF0E0D0;
    config.readMenuBgColorNight = 0xFF121212;
    config.readMenuContainerColor = 0xFFE0D0C0;
    config.readMenuContainerColorNight = 0xFF242424;
    config.readMenuTextColor = 0xFF010203;
    config.readMenuTextColorNight = 0xFFFAFBFC;
    await repository.save(config.copy());
    expect(prefs.containsKey('readBarStyleFollowPage'), isFalse);
    final restored = await repository.load();
    expect(restored.readBarStyle, 2);
    expect(restored.readMenuPaletteStyle, 'vibrant');
    expect(restored.readMenuColorMode, 1);
    expect(restored.readMenuAccentColor, config.readMenuAccentColor);
    expect(restored.readMenuAccentColorNight, config.readMenuAccentColorNight);
    expect(restored.readMenuBgColor, config.readMenuBgColor);
    expect(restored.readMenuBgColorNight, config.readMenuBgColorNight);
    expect(restored.readMenuContainerColor, config.readMenuContainerColor);
    expect(
      restored.readMenuContainerColorNight,
      config.readMenuContainerColorNight,
    );
    expect(restored.readMenuTextColor, config.readMenuTextColor);
    expect(restored.readMenuTextColorNight, config.readMenuTextColorNight);
  });
}
