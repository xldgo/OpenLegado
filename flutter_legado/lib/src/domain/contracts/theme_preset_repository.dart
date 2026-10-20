import '../../models/theme_preset.dart';

/// 本地命名主题的存储边界，与主题文件和关联导入分别处理。
abstract interface class ThemePresetRepository {
  Future<List<ThemePreset>> readAll();
  Future<void> add(ThemePreset preset);
  Future<List<ThemePreset>> removeAt(int index);
}
