import 'package:material_ui/material_ui.dart';

/// 导入状态标签配色（亮暗自适应）
/// [UI_MD3_ALIGNMENT_PLAN.md Batch B B5] 新增=primary、更新=tertiary，亮暗自适应
abstract final class AppColorsExt {
  static Color importNew(ColorScheme scheme) => scheme.primary;

  static Color importUpdate(ColorScheme scheme) => scheme.tertiary;
}
