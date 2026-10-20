import 'package:material_ui/material_ui.dart';

import '../domain/models/appearance_settings.dart';
import 'app_theme.dart';
import 'md3_colors.dart';
import 'theme_engine_parameterized.dart';

/// 已有四色配置的绘制输入；空值表示使用色板对应角色。
@immutable
class ThemeColorOverrides {
  const ThemeColorOverrides({
    this.primary,
    this.accent,
    this.background,
    this.bottomBackground,
  });

  final Color? primary;
  final Color? accent;
  final Color? background;
  final Color? bottomBackground;
}

/// 应用主题的只读输入，不依赖 Provider、持久化或全局设置镜像。
@immutable
class AppThemePreferences {
  const AppThemePreferences({
    this.paletteId = Md3Palettes.defaultId,
    this.style = 'none',
    this.contrastLevel = 0,
    this.amoledDark = false,
    this.cardRadius = AppTheme.defaultCardRadius,
    this.fontFamily,
    this.lightColors = const ThemeColorOverrides(),
    this.darkColors = const ThemeColorOverrides(),
  });

  final String paletteId;
  final String style;
  final double contrastLevel;
  final bool amoledDark;
  final double cardRadius;
  final String? fontFamily;
  final ThemeColorOverrides lightColors;
  final ThemeColorOverrides darkColors;
}

/// 解析配色优先级并通过统一组件入口装配明暗主题。
///
/// 参数化色板沿用日间主色作为两套角色的种子；纯黑先应用，自定义背景后覆盖。
/// 动态取色使用完整系统色板；不支持的一侧沿用参考版的绿色回退色板。
/// 动态模式不叠加自定义四色或参数化风格，避免混合两套配色。
({ThemeData light, ThemeData dark}) resolveAppThemes({
  required AppThemePreferences preferences,
  ColorScheme? lightDynamic,
  ColorScheme? darkDynamic,
}) {
  final useDynamic =
      preferences.paletteId == AppearanceSettings.dynamicPaletteId;
  final palette = useDynamic
      ? Md3Palettes.gr
      : Md3Palettes.byId(preferences.paletteId);
  var effectivePalette = palette;
  if (!useDynamic && preferences.style != 'none') {
    final seed = preferences.lightColors.primary?.toARGB32() ?? palette.seed;
    final roles = buildParameterizedRoles(
      style: preferences.style,
      seed: seed,
      contrastLevel: preferences.contrastLevel,
    );
    effectivePalette = Md3Palette(
      id: '${palette.id}__param',
      label: palette.label,
      seed: seed,
      light: roles.light,
      dark: roles.dark,
    );
  }

  ThemeData assemble(
    Brightness brightness,
    ThemeColorOverrides colors,
    ColorScheme? dynamicColors,
  ) {
    final overrides = useDynamic ? const ThemeColorOverrides() : colors;
    return AppTheme.palette(
      brightness: brightness,
      palette: effectivePalette,
      colorScheme: useDynamic ? dynamicColors : null,
      amoledDark: preferences.amoledDark,
      cardRadius: preferences.cardRadius,
      fontFamily: preferences.fontFamily,
      primary: overrides.primary,
      accent: overrides.accent,
      background: overrides.background,
      bottomBackground: overrides.bottomBackground,
    );
  }

  return (
    light: assemble(Brightness.light, preferences.lightColors, lightDynamic),
    dark: assemble(Brightness.dark, preferences.darkColors, darkDynamic),
  );
}
