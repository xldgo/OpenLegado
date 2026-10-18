import 'ui_settings_values.dart';

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

  /// 液态玻璃：资源就绪时绘制光学背景，未就绪回退 [glass] 底色
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

  /// 顶栏普通背景不透明度 0–1
  final double topBarBackgroundOpacity;

  /// 底栏 label 显示档位
  final BottomBarLabelMode labelVisibilityMode;

  /// 底栏普通背景不透明度 0–1
  final double bottomBarBackgroundOpacity;

  /// 悬浮底栏（64dp 胶囊形态，参考仓默认关）
  final bool useFloatingBottomBar;

  /// 悬浮底栏液态玻璃，独立于普通毛玻璃开关。
  final bool useFloatingBottomBarLiquidGlass;

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

  /// 顶栏高斯模糊 sigma，单位为逻辑像素
  final double topBarBlurSigma;

  /// 顶栏模糊底色不透明度 0–1
  final double topBarBlurTintOpacity;

  /// 底栏高斯模糊 sigma，单位为逻辑像素
  final double bottomBarBlurSigma;

  /// 底栏模糊底色不透明度 0–1
  final double bottomBarBlurTintOpacity;

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
    this.topBarBackgroundOpacity = UiSettingsValues.topBarBackgroundOpacity,
    this.labelVisibilityMode = BottomBarLabelMode.auto,
    this.bottomBarBackgroundOpacity =
        UiSettingsValues.bottomBarBackgroundOpacity,
    this.useFloatingBottomBar = false,
    this.useFloatingBottomBarLiquidGlass = false,
    this.showBottomView = true,
    this.tabletInterface = TabletInterfaceMode.auto,
    this.bookInfoFollowCoverColor = true,
    this.bookInfoNetworkCoverBackground = 'on',
    this.bookInfoDefaultCoverBackground = 'on',
    this.overrideBaseCardCornerRadius = false,
    this.baseCardCornerRadius = 16,
    this.enableBlur = false,
    this.topBarBlurSigma = UiSettingsValues.topBarBlurSigma,
    this.topBarBlurTintOpacity = UiSettingsValues.topBarBlurTintOpacity,
    this.bottomBarBlurSigma = UiSettingsValues.bottomBarBlurSigma,
    this.bottomBarBlurTintOpacity = UiSettingsValues.bottomBarBlurTintOpacity,
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
    double? topBarBackgroundOpacity,
    BottomBarLabelMode? labelVisibilityMode,
    double? bottomBarBackgroundOpacity,
    bool? useFloatingBottomBar,
    bool? useFloatingBottomBarLiquidGlass,
    bool? showBottomView,
    TabletInterfaceMode? tabletInterface,
    bool? bookInfoFollowCoverColor,
    String? bookInfoNetworkCoverBackground,
    String? bookInfoDefaultCoverBackground,
    bool? overrideBaseCardCornerRadius,
    int? baseCardCornerRadius,
    bool? enableBlur,
    double? topBarBlurSigma,
    double? topBarBlurTintOpacity,
    double? bottomBarBlurSigma,
    double? bottomBarBlurTintOpacity,
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
      topBarBackgroundOpacity:
          topBarBackgroundOpacity ?? this.topBarBackgroundOpacity,
      labelVisibilityMode: labelVisibilityMode ?? this.labelVisibilityMode,
      bottomBarBackgroundOpacity:
          bottomBarBackgroundOpacity ?? this.bottomBarBackgroundOpacity,
      useFloatingBottomBar: useFloatingBottomBar ?? this.useFloatingBottomBar,
      useFloatingBottomBarLiquidGlass:
          useFloatingBottomBarLiquidGlass ??
          this.useFloatingBottomBarLiquidGlass,
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
      topBarBlurSigma: topBarBlurSigma ?? this.topBarBlurSigma,
      topBarBlurTintOpacity:
          topBarBlurTintOpacity ?? this.topBarBlurTintOpacity,
      bottomBarBlurSigma: bottomBarBlurSigma ?? this.bottomBarBlurSigma,
      bottomBarBlurTintOpacity:
          bottomBarBlurTintOpacity ?? this.bottomBarBlurTintOpacity,
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
      topBarBackgroundOpacity == other.topBarBackgroundOpacity &&
      labelVisibilityMode == other.labelVisibilityMode &&
      bottomBarBackgroundOpacity == other.bottomBarBackgroundOpacity &&
      useFloatingBottomBar == other.useFloatingBottomBar &&
      useFloatingBottomBarLiquidGlass ==
          other.useFloatingBottomBarLiquidGlass &&
      showBottomView == other.showBottomView &&
      tabletInterface == other.tabletInterface &&
      bookInfoFollowCoverColor == other.bookInfoFollowCoverColor &&
      bookInfoNetworkCoverBackground == other.bookInfoNetworkCoverBackground &&
      bookInfoDefaultCoverBackground == other.bookInfoDefaultCoverBackground &&
      overrideBaseCardCornerRadius == other.overrideBaseCardCornerRadius &&
      baseCardCornerRadius == other.baseCardCornerRadius &&
      enableBlur == other.enableBlur &&
      topBarBlurSigma == other.topBarBlurSigma &&
      topBarBlurTintOpacity == other.topBarBlurTintOpacity &&
      bottomBarBlurSigma == other.bottomBarBlurSigma &&
      bottomBarBlurTintOpacity == other.bottomBarBlurTintOpacity &&
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
    topBarBackgroundOpacity,
    labelVisibilityMode,
    bottomBarBackgroundOpacity,
    useFloatingBottomBar,
    useFloatingBottomBarLiquidGlass,
    showBottomView,
    tabletInterface,
    bookInfoFollowCoverColor,
    bookInfoNetworkCoverBackground,
    bookInfoDefaultCoverBackground,
    overrideBaseCardCornerRadius,
    baseCardCornerRadius,
    enableBlur,
    topBarBlurSigma,
    topBarBlurTintOpacity,
    bottomBarBlurSigma,
    bottomBarBlurTintOpacity,
    wallpaperColorFollow,
    enableItemDivider,
    railExtended,
    themeStyle,
    themeContrastLevel,
    themeAmoled,
  ]);
}
