/// 系统栏普通偏好；平台样式和阅读器显隐由现有控制器处理。— Codex + UI
final class SystemBarSettings {
  const SystemBarSettings({
    this.transparentStatusBar = true,
    this.immNavigationBar = true,
  });

  final bool transparentStatusBar;
  final bool immNavigationBar;

  @override
  bool operator ==(Object other) =>
      other is SystemBarSettings &&
      transparentStatusBar == other.transparentStatusBar &&
      immNavigationBar == other.immNavigationBar;

  @override
  int get hashCode => Object.hash(transparentStatusBar, immNavigationBar);
}
