/// 材质参数的默认值和读写限值；不解释旧字节或百分比编码。— Codex + UI
abstract final class UiSettingsValues {
  static const topBarBackgroundOpacity = 1.0;
  static const bottomBarBackgroundOpacity = 1.0;
  static const topBarBlurTintOpacity = 0.73;
  static const bottomBarBlurTintOpacity = 0.40;
  static const topBarBlurSigma = 24.0;
  static const bottomBarBlurSigma = 8.0;

  static double opacity(double value, {double fallback = 1}) =>
      value.isFinite ? value.clamp(0.0, 1.0) : fallback;

  static double sigma(double value, {required double fallback}) =>
      value.isFinite ? value.clamp(0.0, 48.0) : fallback;

  static int cardRadius(int value) => value.clamp(4, 28);
}
