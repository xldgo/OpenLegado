import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_legado/src/theme/app_theme.dart';
import 'package:flutter_legado/src/domain/models/appearance_settings.dart';
import 'package:flutter_legado/src/theme/app_theme_resolver.dart';
import 'package:flutter_legado/src/theme/md3_colors.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const day = ThemeColorOverrides(
    primary: Color(0xFF123456),
    accent: Color(0xFFABCDEF),
    background: Color(0xFFF0E0D0),
    bottomBackground: Color(0xFFE0D0C0),
  );
  const night = ThemeColorOverrides(
    primary: Color(0xFF654321),
    accent: Color(0xFFEDCBA0),
    background: Color(0xFF121314),
    bottomBackground: Color(0xFF242526),
  );

  BorderRadiusGeometry? cardRadius(ThemeData theme) =>
      (theme.cardTheme.shape as RoundedRectangleBorder).borderRadius;

  void expectCustomColors(ThemeData theme, ThemeColorOverrides colors) {
    expect(theme.appBarTheme.backgroundColor, colors.primary);
    expect(theme.colorScheme.primary, colors.accent);
    expect(theme.scaffoldBackgroundColor, colors.background);
    expect(theme.navigationBarTheme.backgroundColor, colors.bottomBackground);
  }

  test('全部内置色板与未知 ID 保留明暗角色及默认组件样式', () {
    for (final id in [...Md3Palettes.all.map((p) => p.id), 'unknown']) {
      final themes = resolveAppThemes(
        preferences: AppThemePreferences(paletteId: id),
      );
      final palette = Md3Palettes.byId(id);
      for (final theme in [themes.light, themes.dark]) {
        final original = AppTheme.palette(
          brightness: theme.brightness,
          palette: palette,
        );
        expect(theme.colorScheme, original.colorScheme, reason: id);
        expect(theme.appBarTheme, original.appBarTheme, reason: id);
        expect(theme.cardTheme, original.cardTheme, reason: id);
        expect(theme.inputDecorationTheme, original.inputDecorationTheme);
        expect(theme.pageTransitionsTheme, original.pageTransitionsTheme);
      }
    }
  });

  test('四色配置区分日夜；强调色与标题栏主色保持原有映射', () {
    final themes = resolveAppThemes(
      preferences: const AppThemePreferences(
        lightColors: day,
        darkColors: night,
      ),
    );
    expectCustomColors(themes.light, day);
    expectCustomColors(themes.dark, night);
    expect(themes.light.colorScheme.onPrimary, Colors.black87);
    expect(themes.light.appBarTheme.foregroundColor, Colors.white);
  });

  test('动态取色不可用时明暗分别使用绿色回退，不混入自定义四色', () {
    final themes = resolveAppThemes(
      preferences: const AppThemePreferences(
        paletteId: AppearanceSettings.dynamicPaletteId,
        style: 'expressive',
        lightColors: day,
        darkColors: night,
      ),
    );
    expect(themes.light.colorScheme, md3LightScheme(Md3Palettes.gr));
    expect(themes.dark.colorScheme, md3DarkScheme(Md3Palettes.gr));
  });

  test('动态取色保留完整角色，缺失的一侧独立回退', () {
    final dynamic = ColorScheme.fromSeed(seedColor: Colors.green);
    final themes = resolveAppThemes(
      preferences: const AppThemePreferences(
        paletteId: AppearanceSettings.dynamicPaletteId,
        style: 'monochrome',
        contrastLevel: 0.5,
        lightColors: day,
        darkColors: night,
      ),
      lightDynamic: dynamic,
    );
    expect(themes.light.colorScheme, dynamic);
    expect(themes.light.appBarTheme.backgroundColor, dynamic.surface);
    expect(themes.light.scaffoldBackgroundColor, dynamic.surface);
    expect(
      themes.light.navigationBarTheme.backgroundColor,
      dynamic.surfaceContainer,
    );
    expect(themes.light.cardTheme.color, dynamic.surfaceContainerLowest);
    expect(themes.dark.colorScheme, md3DarkScheme(Md3Palettes.gr));
  });

  test('系统深色和纯黑模式仍沿用统一组件装配', () {
    final dynamic = ColorScheme.fromSeed(
      seedColor: Colors.purple,
      brightness: Brightness.dark,
    );
    final themes = resolveAppThemes(
      preferences: const AppThemePreferences(
        paletteId: AppearanceSettings.dynamicPaletteId,
        amoledDark: true,
        cardRadius: 14,
      ),
      darkDynamic: dynamic,
    );
    expect(themes.dark.colorScheme.primary, dynamic.primary);
    expect(
      themes.dark.colorScheme.onPrimaryContainer,
      dynamic.onPrimaryContainer,
    );
    expect(themes.dark.colorScheme.surface, Colors.black);
    expect(themes.dark.scaffoldBackgroundColor, Colors.black);
    expect(cardRadius(themes.dark), BorderRadius.circular(14));
  });

  test('选择普通配色时忽略平台动态色并保留自定义配置', () {
    final dynamic = ColorScheme.fromSeed(seedColor: Colors.green);
    final themes = resolveAppThemes(
      preferences: const AppThemePreferences(
        lightColors: day,
        darkColors: night,
      ),
      lightDynamic: dynamic,
      darkDynamic: dynamic,
    );
    expectCustomColors(themes.light, day);
    expectCustomColors(themes.dark, night);
  });

  test('参数化风格和对比度生效，自定义四色继续覆盖生成结果', () {
    final standard = resolveAppThemes(
      preferences: const AppThemePreferences(style: 'tonalSpot'),
    );
    final highContrast = resolveAppThemes(
      preferences: const AppThemePreferences(
        style: 'tonalSpot',
        contrastLevel: 0.5,
      ),
    );
    final monochrome = resolveAppThemes(
      preferences: const AppThemePreferences(style: 'monochrome'),
    );
    expect(
      standard.light.colorScheme.outline,
      isNot(highContrast.light.colorScheme.outline),
    );
    expect(
      standard.dark.colorScheme.outline,
      isNot(highContrast.dark.colorScheme.outline),
    );
    expect(
      standard.light.colorScheme.primary,
      isNot(monochrome.light.colorScheme.primary),
    );
    final custom = resolveAppThemes(
      preferences: const AppThemePreferences(
        style: 'expressive',
        contrastLevel: 0.5,
        lightColors: day,
        darkColors: night,
      ),
    );
    expectCustomColors(custom.light, day);
    expectCustomColors(custom.dark, night);
  });

  test('日间主色作为共同种子，夜间主色只覆盖夜间标题栏', () {
    final first = resolveAppThemes(
      preferences: const AppThemePreferences(
        style: 'tonalSpot',
        lightColors: day,
        darkColors: night,
      ),
    );
    final changedNight = resolveAppThemes(
      preferences: const AppThemePreferences(
        style: 'tonalSpot',
        lightColors: day,
        darkColors: ThemeColorOverrides(primary: Colors.blue),
      ),
    );
    expect(first.light.colorScheme, changedNight.light.colorScheme);
    expect(
      first.dark.colorScheme.tertiary,
      changedNight.dark.colorScheme.tertiary,
    );
    expect(changedNight.dark.appBarTheme.backgroundColor, Colors.blue);
  });

  test('纯黑对默认和参数化主题生效，自定义背景仍有更高优先级', () {
    for (final style in ['none', 'tonalSpot']) {
      final themes = resolveAppThemes(
        preferences: AppThemePreferences(style: style, amoledDark: true),
      );
      expect(themes.dark.colorScheme.surface, Colors.black);
      expect(themes.dark.scaffoldBackgroundColor, Colors.black);
      expect(themes.dark.cardTheme.color, const Color(0xFF0A0A0A));
      expect(themes.light.colorScheme.surface, isNot(Colors.black));
      final custom = resolveAppThemes(
        preferences: AppThemePreferences(
          style: style,
          amoledDark: true,
          darkColors: night,
        ),
      );
      expectCustomColors(custom.dark, night);
    }
  });

  test('组件装配只使用显式圆角，局部换色继承已解析形状', () {
    final themes = resolveAppThemes(
      preferences: const AppThemePreferences(cardRadius: 8),
    );
    final repeated = resolveAppThemes(
      preferences: const AppThemePreferences(cardRadius: 8),
    );
    expect(cardRadius(themes.light), BorderRadius.circular(8));
    expect(cardRadius(themes.dark), BorderRadius.circular(8));
    expect(themes.light.cardTheme, repeated.light.cardTheme);
    expect(cardRadius(AppTheme.light), BorderRadius.circular(20));
    final local = AppTheme.withColorScheme(
      themes.dark,
      ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark),
    );
    expect(local.cardTheme.shape, themes.dark.cardTheme.shape);
    expect(local.cardTheme.color, local.colorScheme.surfaceContainerLow);
  });

  test('局部换色同步完整组件，保留平台、字体、密度与页面转场', () {
    final base = AppTheme.light.copyWith(
      platform: TargetPlatform.iOS,
      textTheme: AppTheme.light.textTheme.apply(fontFamily: 'reader-font'),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      splashFactory: NoSplash.splashFactory,
    );
    final scheme = ColorScheme.fromSeed(seedColor: Colors.green);
    final local = AppTheme.withColorScheme(base, scheme);
    expect(local.scaffoldBackgroundColor, scheme.surface);
    expect(local.cardTheme.color, scheme.surfaceContainerLow);
    expect(local.inputDecorationTheme.fillColor, scheme.surfaceContainerLow);
    expect(local.dialogTheme.backgroundColor, scheme.surfaceContainer);
    expect(local.bottomSheetTheme.backgroundColor, scheme.surfaceContainer);
    expect(
      local.menuTheme.style?.backgroundColor?.resolve({}),
      scheme.surfaceContainerLow,
    );
    expect(
      local.floatingActionButtonTheme.backgroundColor,
      scheme.primaryContainer,
    );
    expect(local.iconButtonTheme.style?.foregroundColor, isNull);
    expect(local.platform, base.platform);
    expect(local.pageTransitionsTheme, base.pageTransitionsTheme);
    expect(local.textTheme.bodyMedium?.fontFamily, 'reader-font');
    expect(local.textTheme.bodyMedium?.color, scheme.onSurface);
    expect(local.visualDensity, base.visualDensity);
    expect(local.materialTapTargetSize, base.materialTapTargetSize);
    expect(local.splashFactory, base.splashFactory);
  });

  test('完整主题过渡插值卡片与弹层，输入框到达目标配色', () {
    final base = AppTheme.light;
    final target = AppTheme.withColorScheme(
      base,
      ColorScheme.fromSeed(seedColor: Colors.blue),
    );
    final midway = ThemeData.lerp(base, target, 0.5);
    expect(
      midway.cardTheme.color,
      Color.lerp(base.cardTheme.color, target.cardTheme.color, 0.5),
    );
    // 标准 ThemeData 对输入框主题在中点切换；终点必须包含完整目标主题。
    expect(
      ThemeData.lerp(base, target, 1).inputDecorationTheme,
      target.inputDecorationTheme,
    );
    expect(
      midway.dialogTheme.backgroundColor,
      Color.lerp(
        base.dialogTheme.backgroundColor,
        target.dialogTheme.backgroundColor,
        0.5,
      ),
    );
  });
}
