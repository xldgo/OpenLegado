import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:material_ui/material_ui.dart';

import 'app_surface_material.dart';

/// 第三方材质只从应用主题取得亮度，不另行跟随系统配色。— Codex + UI
class AppGlassHost extends StatelessWidget {
  const AppGlassHost({super.key, required this.available, required this.child});

  final bool available;
  final Widget child;

  @override
  Widget build(BuildContext context) => AppGlassScope(
    available: available,
    child: GlassTheme(
      data: GlassThemeData.simple(
        brightness: Theme.of(context).brightness,
        quality: GlassQuality.standard,
      ),
      child: GlassAccessibilityScope(child: child),
    ),
  );
}

/// 无应用宿主的组件默认保留普通材质，避免未预热时启动着色器。
class AppGlassScope extends InheritedWidget {
  const AppGlassScope({
    super.key,
    required this.available,
    required super.child,
  });

  final bool available;

  static bool availableOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppGlassScope>()?.available ??
      false;

  @override
  bool updateShouldNotify(AppGlassScope oldWidget) =>
      available != oldWidget.available;
}

/// 仅在此处将应用材质输入转换成库参数，后续组件不自行换算单位。
abstract final class AppGlassStyle {
  static LiquidGlassSettings resolve(AppSurfaceMaterial material) =>
      LiquidGlassSettings(
        glassColor: material.color,
        // 初始按逻辑像素传入，实际观感由设备复验校准；不保证与高斯模糊等效。
        blur: material.blurSigma,
        bodyMode: GlassBodyMode.clear,
      );
}
