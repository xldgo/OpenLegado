import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;

import '../../theme/app_theme.dart';
import '../../theme/app_theme_resolver.dart';
import '../ui_settings/ui_settings_notifier.dart';
import 'theme_colors_notifier.dart';
import 'theme_notifier.dart';

/// 从现有状态派生绘制输入；布局或背景图片变化不重算配色偏好。
final appThemePreferencesProvider = riverpod.Provider<AppThemePreferences>((
  ref,
) {
  final paletteId = ref.watch(themeNotifierProvider.select((s) => s.paletteId));
  final (style, contrast, amoled, overrideRadius, radius) = ref.watch(
    uiSettingsProvider.select(
      (s) => (
        s.themeStyle,
        s.themeContrastLevel,
        s.themeAmoled,
        s.overrideBaseCardCornerRadius,
        s.baseCardCornerRadius,
      ),
    ),
  );
  final (
    primary,
    accent,
    background,
    bottom,
    nightPrimary,
    nightAccent,
    nightBackground,
    nightBottom,
  ) = ref.watch(
    themeColorsProvider.select(
      (s) => (
        s.primary,
        s.accent,
        s.background,
        s.bottomBackground,
        s.primaryNight,
        s.accentNight,
        s.backgroundNight,
        s.bottomBackgroundNight,
      ),
    ),
  );
  Color? color(int? value) => value == null ? null : Color(value);
  return AppThemePreferences(
    paletteId: paletteId,
    style: style,
    contrastLevel: double.tryParse(contrast) ?? 0,
    amoledDark: amoled,
    cardRadius: overrideRadius ? radius.toDouble() : AppTheme.defaultCardRadius,
    lightColors: ThemeColorOverrides(
      primary: color(primary),
      accent: color(accent),
      background: color(background),
      bottomBackground: color(bottom),
    ),
    darkColors: ThemeColorOverrides(
      primary: color(nightPrimary),
      accent: color(nightAccent),
      background: color(nightBackground),
      bottomBackground: color(nightBottom),
    ),
  );
});
