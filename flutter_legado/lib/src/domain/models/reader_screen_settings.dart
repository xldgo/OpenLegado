/// 阅读屏幕、系统栏与安全区偏好；平台执行由阅读页面负责。— Codex + UI
final class ReaderScreenSettings {
  const ReaderScreenSettings({
    this.orientation = 0,
    this.keepScreenOnSeconds = 0,
    this.hideStatusBar = false,
    this.hideNavigationBar = false,
    this.avoidDisplayCutouts = false,
  });

  /// 0跟随系统、1竖屏、2横屏、3传感器、4反向竖屏、5反向横屏。
  final int orientation;

  /// -1常亮、0系统、60/300/600秒；到期解除防休眠，由系统决定熄屏时间。
  final int keepScreenOnSeconds;
  final bool hideStatusBar;
  final bool hideNavigationBar;
  final bool avoidDisplayCutouts;

  @override
  bool operator ==(Object other) =>
      other is ReaderScreenSettings &&
      orientation == other.orientation &&
      keepScreenOnSeconds == other.keepScreenOnSeconds &&
      hideStatusBar == other.hideStatusBar &&
      hideNavigationBar == other.hideNavigationBar &&
      avoidDisplayCutouts == other.avoidDisplayCutouts;

  @override
  int get hashCode => Object.hash(
    orientation,
    keepScreenOnSeconds,
    hideStatusBar,
    hideNavigationBar,
    avoidDisplayCutouts,
  );
}
