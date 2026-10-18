import 'package:material_ui/material_ui.dart';

import '../domain/models/ui_settings.dart';
import '../domain/models/ui_settings_values.dart';

/// 共享背景材质的最终绘制参数；不包含组件内容透明度。— Codex + UI
@immutable
final class AppSurfaceMaterial {
  const AppSurfaceMaterial._({required this.color, required this.blurSigma});

  factory AppSurfaceMaterial.resolve({
    required Color color,
    required bool blurEnabled,
    required double backgroundOpacity,
    required double blurTintOpacity,
    required double blurSigma,
  }) {
    final opacity = UiSettingsValues.opacity(
      blurEnabled ? blurTintOpacity : backgroundOpacity,
    );
    return AppSurfaceMaterial._(
      color: color.withValues(alpha: color.a * opacity),
      blurSigma: blurEnabled && color.a > 0
          ? UiSettingsValues.sigma(blurSigma, fallback: 0)
          : 0,
    );
  }

  factory AppSurfaceMaterial.topBar({
    required Color color,
    required UiSettings settings,
  }) => AppSurfaceMaterial.resolve(
    color: color,
    blurEnabled: settings.enableBlur,
    backgroundOpacity: settings.topBarBackgroundOpacity,
    blurTintOpacity: settings.topBarBlurTintOpacity,
    blurSigma: settings.topBarBlurSigma,
  );

  factory AppSurfaceMaterial.bottomBar({
    required Color color,
    required UiSettings settings,
    bool liquidGlass = false,
  }) => AppSurfaceMaterial.resolve(
    color: color,
    blurEnabled: settings.enableBlur || liquidGlass,
    backgroundOpacity: settings.bottomBarBackgroundOpacity,
    blurTintOpacity: settings.bottomBarBlurTintOpacity,
    blurSigma: settings.bottomBarBlurSigma,
  );

  /// 按钮独立于整栏背景设置，普通回退与光学材质使用同一底色。
  factory AppSurfaceMaterial.button({required Color color}) =>
      AppSurfaceMaterial.resolve(
        color: color,
        blurEnabled: true,
        backgroundOpacity: buttonTintOpacity,
        blurTintOpacity: buttonTintOpacity,
        blurSigma: buttonBlurSigma,
      );

  final Color color;
  final double blurSigma;
  bool get hasBlur => blurSigma > 0;

  /// 按钮与合并胶囊使用同一半透明底色与轻量模糊参数。
  static const buttonTintOpacity = 0.5;
  static const buttonBlurSigma = 8.0;
  static Color buttonColor(Color color) =>
      color.withValues(alpha: color.a * buttonTintOpacity);
}
