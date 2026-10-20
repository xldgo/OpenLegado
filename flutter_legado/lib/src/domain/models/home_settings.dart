/// 主界面导航偏好，不包含当前页或界面加载状态。— Codex + UI
final class HomeSettings {
  const HomeSettings({
    this.showDiscovery = true,
    this.showRss = true,
    this.defaultHomePage = 'bookshelf',
  });

  final bool showDiscovery;
  final bool showRss;
  final String defaultHomePage;

  HomeSettings copyWith({
    bool? showDiscovery,
    bool? showRss,
    String? defaultHomePage,
  }) => HomeSettings(
    showDiscovery: showDiscovery ?? this.showDiscovery,
    showRss: showRss ?? this.showRss,
    defaultHomePage: defaultHomePage ?? this.defaultHomePage,
  );

  @override
  bool operator ==(Object other) =>
      other is HomeSettings &&
      showDiscovery == other.showDiscovery &&
      showRss == other.showRss &&
      defaultHomePage == other.defaultHomePage;

  @override
  int get hashCode => Object.hash(showDiscovery, showRss, defaultHomePage);
}
