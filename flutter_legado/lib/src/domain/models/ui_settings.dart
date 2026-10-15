/// 顶栏按钮样式档位（对齐参考仓 TopBarButtonStyle）
enum TopBarButtonStyle {
  /// 平面：40dp 容器 / 图标 24dp，无底色（参考仓 "plain"）
  plain,

  /// tonal：36dp 容器 / 图标 20dp，secondaryContainer 底（参考仓默认 "tonal"）
  tonal,

  /// 描边：36dp 容器，透明底 + 1dp outlineVariant 描边（"outlined"）
  outlined,

  /// 玻璃：36dp 容器，surface 半透明实色（参考仓 blur 档的实色回退，"glass"）
  glass,

  /// 液态玻璃：与 [glass] 同规格实色版（参考仓 "liquid"，blur 家族接通后差异化）
  liquidGlass;

  /// 从持久化字符串解析（未知值回退 [tonal]）
  static TopBarButtonStyle fromName(String? name) {
    for (final s in TopBarButtonStyle.values) {
      if (s.name == name) return s;
    }
    return TopBarButtonStyle.tonal;
  }
}

/// 底栏 label 显示档位（对齐参考仓 labelVisibilityMode）
enum BottomBarLabelMode {
  /// 仅选中显示 label（参考仓 "auto" 默认）
  auto,

  /// 全部常显（"labeled"）
  labeled,

  /// 纯图标（"unlabeled"）
  unlabeled;

  /// 从持久化字符串解析（未知值回退 [auto]）
  static BottomBarLabelMode fromName(String? name) {
    for (final m in BottomBarLabelMode.values) {
      if (m.name == name) return m;
    }
    return BottomBarLabelMode.auto;
  }
}

/// 平板/大屏导航形态（对齐参考仓 tabletInterface）
enum TabletInterfaceMode {
  /// 自动：sw≥600 启用 Rail（"auto" 默认）
  auto,

  /// 始终启用 Rail（"always"）
  always,

  /// 仅横屏启用（"landscape"）
  landscape,

  /// 不启用（"off"）
  off;

  /// 从持久化字符串解析（未知值回退 [auto]）
  static TabletInterfaceMode fromName(String? name) {
    for (final m in TabletInterfaceMode.values) {
      if (m.name == name) return m;
    }
    return TabletInterfaceMode.auto;
  }
}

/// 完整界面偏好，与组件、持久化及加载状态解耦。— Codex + UI
final class UiSettings {
  /// 顶栏按钮样式档位
  final TopBarButtonStyle topBarButtonStyle;

  /// 顶栏 actions 合并进胶囊容器
  final bool mergeTopBarActions;

  /// MediumFlexible 大顶栏形态（true=LargeTitle 系保持展开大标题）
  final bool useFlexibleTopAppBar;

  /// 顶栏不透明度 0-100
  final int topBarOpacity;

  /// 底栏 label 显示档位
  final BottomBarLabelMode labelVisibilityMode;

  /// 底栏不透明度 0-100
  final int bottomBarOpacity;

  /// 悬浮底栏（64dp 胶囊形态，参考仓默认关）
  final bool useFloatingBottomBar;

  /// 显示底栏（参考仓 showBottomView）
  final bool showBottomView;

  /// 平板/大屏导航形态
  final TabletInterfaceMode tabletInterface;

  /// 详情页跟随封面取色换肤
  final bool bookInfoFollowCoverColor;

  /// 详情页网络封面背景三档：off/off_for_default/on
  final String bookInfoNetworkCoverBackground;

  /// 详情页默认封面背景三档
  final String bookInfoDefaultCoverBackground;

  /// 覆写基础卡片圆角
  final bool overrideBaseCardCornerRadius;

  /// 基础卡片圆角值 4-28
  final int baseCardCornerRadius;

  /// 启用毛玻璃（BackdropFilter，默认关）
  final bool enableBlur;

  /// 顶栏模糊半径 dp
  final int topBarBlurRadius;

  /// 顶栏底色透明度 0-255
  final int topBarBlurAlpha;

  /// 悬浮底栏模糊半径 dp
  final int bottomBarBlurRadius;

  /// 悬浮底栏底色透明度 0-255
  final int bottomBarBlurAlpha;

  /// 跟随壁纸取色（Android 12+ Material You / iOS 动态色均接通）
  final bool wallpaperColorFollow;

  /// 设置行分隔线开关
  final bool enableItemDivider;

  /// 大屏侧栏展开态（持久化）
  final bool railExtended;

  /// 主题引擎 paletteStyle（'none'=关闭参数化，9 档见 kPaletteStyles）
  final String themeStyle;

  /// 主题引擎对比度（'0.0'/'0.5'/'1.0'）
  final String themeContrastLevel;

  /// AMOLED 纯黑（仅暗色生效）
  final bool themeAmoled;

  const UiSettings({
    this.topBarButtonStyle = TopBarButtonStyle.tonal,
    this.mergeTopBarActions = false,
    this.useFlexibleTopAppBar = true,
    this.topBarOpacity = 100,
    this.labelVisibilityMode = BottomBarLabelMode.auto,
    this.bottomBarOpacity = 100,
    this.useFloatingBottomBar = false,
    this.showBottomView = true,
    this.tabletInterface = TabletInterfaceMode.auto,
    this.bookInfoFollowCoverColor = true,
    this.bookInfoNetworkCoverBackground = 'on',
    this.bookInfoDefaultCoverBackground = 'on',
    this.overrideBaseCardCornerRadius = false,
    this.baseCardCornerRadius = 16,
    this.enableBlur = false,
    this.topBarBlurRadius = 24,
    this.topBarBlurAlpha = 73,
    this.bottomBarBlurRadius = 8,
    this.bottomBarBlurAlpha = 40,
    this.wallpaperColorFollow = false,
    this.enableItemDivider = false,
    this.railExtended = false,
    this.themeStyle = 'none',
    this.themeContrastLevel = '0.0',
    this.themeAmoled = false,
  });

  UiSettings copyWith({
    TopBarButtonStyle? topBarButtonStyle,
    bool? mergeTopBarActions,
    bool? useFlexibleTopAppBar,
    int? topBarOpacity,
    BottomBarLabelMode? labelVisibilityMode,
    int? bottomBarOpacity,
    bool? useFloatingBottomBar,
    bool? showBottomView,
    TabletInterfaceMode? tabletInterface,
    bool? bookInfoFollowCoverColor,
    String? bookInfoNetworkCoverBackground,
    String? bookInfoDefaultCoverBackground,
    bool? overrideBaseCardCornerRadius,
    int? baseCardCornerRadius,
    bool? enableBlur,
    int? topBarBlurRadius,
    int? topBarBlurAlpha,
    int? bottomBarBlurRadius,
    int? bottomBarBlurAlpha,
    bool? wallpaperColorFollow,
    bool? enableItemDivider,
    bool? railExtended,
    String? themeStyle,
    String? themeContrastLevel,
    bool? themeAmoled,
  }) {
    return UiSettings(
      topBarButtonStyle: topBarButtonStyle ?? this.topBarButtonStyle,
      mergeTopBarActions: mergeTopBarActions ?? this.mergeTopBarActions,
      useFlexibleTopAppBar: useFlexibleTopAppBar ?? this.useFlexibleTopAppBar,
      topBarOpacity: topBarOpacity ?? this.topBarOpacity,
      labelVisibilityMode: labelVisibilityMode ?? this.labelVisibilityMode,
      bottomBarOpacity: bottomBarOpacity ?? this.bottomBarOpacity,
      useFloatingBottomBar: useFloatingBottomBar ?? this.useFloatingBottomBar,
      showBottomView: showBottomView ?? this.showBottomView,
      tabletInterface: tabletInterface ?? this.tabletInterface,
      bookInfoFollowCoverColor:
          bookInfoFollowCoverColor ?? this.bookInfoFollowCoverColor,
      bookInfoNetworkCoverBackground:
          bookInfoNetworkCoverBackground ?? this.bookInfoNetworkCoverBackground,
      bookInfoDefaultCoverBackground:
          bookInfoDefaultCoverBackground ?? this.bookInfoDefaultCoverBackground,
      overrideBaseCardCornerRadius:
          overrideBaseCardCornerRadius ?? this.overrideBaseCardCornerRadius,
      baseCardCornerRadius: baseCardCornerRadius ?? this.baseCardCornerRadius,
      enableBlur: enableBlur ?? this.enableBlur,
      topBarBlurRadius: topBarBlurRadius ?? this.topBarBlurRadius,
      topBarBlurAlpha: topBarBlurAlpha ?? this.topBarBlurAlpha,
      bottomBarBlurRadius: bottomBarBlurRadius ?? this.bottomBarBlurRadius,
      bottomBarBlurAlpha: bottomBarBlurAlpha ?? this.bottomBarBlurAlpha,
      wallpaperColorFollow: wallpaperColorFollow ?? this.wallpaperColorFollow,
      enableItemDivider: enableItemDivider ?? this.enableItemDivider,
      railExtended: railExtended ?? this.railExtended,
      themeStyle: themeStyle ?? this.themeStyle,
      themeContrastLevel: themeContrastLevel ?? this.themeContrastLevel,
      themeAmoled: themeAmoled ?? this.themeAmoled,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is UiSettings &&
      topBarButtonStyle == other.topBarButtonStyle &&
      mergeTopBarActions == other.mergeTopBarActions &&
      useFlexibleTopAppBar == other.useFlexibleTopAppBar &&
      topBarOpacity == other.topBarOpacity &&
      labelVisibilityMode == other.labelVisibilityMode &&
      bottomBarOpacity == other.bottomBarOpacity &&
      useFloatingBottomBar == other.useFloatingBottomBar &&
      showBottomView == other.showBottomView &&
      tabletInterface == other.tabletInterface &&
      bookInfoFollowCoverColor == other.bookInfoFollowCoverColor &&
      bookInfoNetworkCoverBackground == other.bookInfoNetworkCoverBackground &&
      bookInfoDefaultCoverBackground == other.bookInfoDefaultCoverBackground &&
      overrideBaseCardCornerRadius == other.overrideBaseCardCornerRadius &&
      baseCardCornerRadius == other.baseCardCornerRadius &&
      enableBlur == other.enableBlur &&
      topBarBlurRadius == other.topBarBlurRadius &&
      topBarBlurAlpha == other.topBarBlurAlpha &&
      bottomBarBlurRadius == other.bottomBarBlurRadius &&
      bottomBarBlurAlpha == other.bottomBarBlurAlpha &&
      wallpaperColorFollow == other.wallpaperColorFollow &&
      enableItemDivider == other.enableItemDivider &&
      railExtended == other.railExtended &&
      themeStyle == other.themeStyle &&
      themeContrastLevel == other.themeContrastLevel &&
      themeAmoled == other.themeAmoled;

  @override
  int get hashCode => Object.hashAll([
    topBarButtonStyle,
    mergeTopBarActions,
    useFlexibleTopAppBar,
    topBarOpacity,
    labelVisibilityMode,
    bottomBarOpacity,
    useFloatingBottomBar,
    showBottomView,
    tabletInterface,
    bookInfoFollowCoverColor,
    bookInfoNetworkCoverBackground,
    bookInfoDefaultCoverBackground,
    overrideBaseCardCornerRadius,
    baseCardCornerRadius,
    enableBlur,
    topBarBlurRadius,
    topBarBlurAlpha,
    bottomBarBlurRadius,
    bottomBarBlurAlpha,
    wallpaperColorFollow,
    enableItemDivider,
    railExtended,
    themeStyle,
    themeContrastLevel,
    themeAmoled,
  ]);
}
