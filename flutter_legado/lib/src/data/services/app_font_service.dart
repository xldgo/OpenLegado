import '../../domain/contracts/appearance_settings_repository.dart';
import '../../platform/app_font_picker.dart';
import '../../domain/contracts/font_catalog.dart';

/// 先加载字体，后保存界面选择；不写阅读正文或标题偏好。— Codex + UI
final class AppFontService {
  AppFontService({
    required this.settings,
    required this.catalog,
    required this.picker,
  });
  final AppearanceSettingsRepository settings;
  final FontCatalog catalog;
  final AppFontPicker picker;

  Future<void> select(String family) async {
    await catalog.loadFamily(family);
    await settings.update((current) => current.copyWith(fontFamily: family));
  }

  Future<String?> importFont() async {
    final selected = await picker.pick();
    if (selected == null) return null;
    final font = await catalog.importFont(selected.name, selected.bytes);
    await select(font.family);
    return font.label;
  }
}
