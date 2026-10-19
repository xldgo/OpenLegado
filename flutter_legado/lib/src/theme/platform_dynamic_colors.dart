import 'package:material_ui/material_ui.dart';

/// 共享应用入口取得的系统色板，预览不再重复请求平台插件。— Codex + UI
class PlatformDynamicColors extends InheritedWidget {
  const PlatformDynamicColors({
    super.key,
    required this.light,
    required this.dark,
    required super.child,
  });

  final ColorScheme? light;
  final ColorScheme? dark;

  static ColorScheme? of(BuildContext context, Brightness brightness) {
    final colors = context
        .dependOnInheritedWidgetOfExactType<PlatformDynamicColors>();
    return brightness == Brightness.light ? colors?.light : colors?.dark;
  }

  @override
  bool updateShouldNotify(PlatformDynamicColors oldWidget) =>
      light != oldWidget.light || dark != oldWidget.dark;
}
