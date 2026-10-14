import '../models/theme_colors_settings.dart';

/// 颜色覆盖与背景路径的偏好边界；命名主题列表单独存储。— Codex + UI
abstract interface class ThemeColorsSettingsRepository {
  ThemeColorsSettings get current;
  Stream<ThemeColorsSettings> watch();
  Future<ThemeColorsSettings> load();
  Future<void> reload();
  Future<void> setColors(Map<ThemeColorRole, int?> colors);
  Future<void> setBgImage({String? day, String? night});
}
