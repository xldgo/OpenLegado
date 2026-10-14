import 'dart:ui';

/// 边距区域（对标原版 PaddingConfigDialog.Region）
enum PaddingRegion { header, body, footer }

/// 点击区域可映射的功能
enum TapAction {
  none,
  prevPage,
  nextPage,
  toggleControls,
  openCatalog;

  String get label {
    switch (this) {
      case TapAction.none:
        return '无操作';
      case TapAction.prevPage:
        return '上一页/章';
      case TapAction.nextPage:
        return '下一页/章';
      case TapAction.toggleControls:
        return '切换工具栏';
      case TapAction.openCatalog:
        return '打开目录';
    }
  }
}

/// 阅读配置与编辑副本；存储及共享状态由独立入口管理。
class ReaderAdvancedConfig {
  // 自动翻页
  bool autoPageTurn;
  double autoPageTurnInterval; // 秒
  bool autoPageTurnForward; // true=下一章 false=上一章

  // 点击区域映射
  static const defaultTapActions = <TapAction>[
    TapAction.prevPage,
    TapAction.prevPage,
    TapAction.nextPage,
    TapAction.prevPage,
    TapAction.toggleControls,
    TapAction.nextPage,
    TapAction.prevPage,
    TapAction.nextPage,
    TapAction.nextPage,
  ];
  final List<TapAction> tapActions;

  /// 按实际正文区域的等分九宫格判断，保留左右边缘防误触。
  TapAction actionForPosition(Offset position, Size size) {
    if (!size.width.isFinite ||
        !size.height.isFinite ||
        size.width <= 0 ||
        size.height <= 0 ||
        !position.dx.isFinite ||
        !position.dy.isFinite ||
        position.dx < 0 ||
        position.dy < 0 ||
        position.dx >= size.width ||
        position.dy >= size.height) {
      return TapAction.none;
    }
    final deadZone = pageTouchClick.toDouble().clamp(
      0.0,
      (size.width / 2 - 1).clamp(0.0, double.infinity),
    );
    if (position.dx < deadZone || position.dx > size.width - deadZone) {
      return TapAction.none;
    }
    final column = (position.dx / size.width * 3).floor().clamp(0, 2);
    final row = (position.dy / size.height * 3).floor().clamp(0, 2);
    return tapActions[row * 3 + column];
  }

  static List<TapAction> _copyTapActions(List<TapAction>? actions) {
    if (actions != null && actions.length != 9) {
      throw ArgumentError.value(actions.length, 'tapActions', '必须包含九个区域');
    }
    return List<TapAction>.of(actions ?? defaultTapActions, growable: false);
  }

  // 段落间距
  double paragraphSpacing;

  // [UI-fix v2.0.2 | 2026-08-06] 对标原版 ReadBookConfig：
  // 字距调节/首行缩进/两端对齐（MoreConfig textFullJustify） — Qoder
  // [UI-fix v2.0.4 | 2026-08-08] 字距语义升级为 em（-0.5~1.0，对标原版
  // dsbTextLetterSpacing (it-50)/100，渲染时乘以字号转 px）；首行缩进由
  // bool 升级为 int 档位（0-3 字符，对标原版 tvTextIndent 缩进选择），
  // 旧 bool 值兼容读取：true→2、false→0 — Qoder
  double letterSpacing;
  int paragraphIndent;
  bool textFullJustify;

  /// 文字字重（0=常规、1=粗体、2=细体）与正文斜体。
  int textBold;
  bool italic;

  // [UI-fix v2.0.3 | 2026-08-06] 页面边距（对标原版 ReadBookConfig
  // paddingTop/paddingBottom/paddingLeft/paddingRight） — Qoder
  double pageMarginTop;
  double pageMarginBottom;
  double pageMarginLeft;
  double pageMarginRight;

  // [UI-fix v2.0.57 | 2026-08-14] 页眉/页脚边距（对标 ReadBookConfig
  // headerPadding*/footerPadding*）— Cursor UI
  double headerPaddingTop;
  double headerPaddingBottom;
  double headerPaddingLeft;
  double headerPaddingRight;
  double footerPaddingTop;
  double footerPaddingBottom;
  double footerPaddingLeft;
  double footerPaddingRight;
  bool showHeaderLine;
  bool showFooterLine;

  // [UI-fix v2.0.57 | 2026-08-14] 阅读提示信息（对标 TipConfigDialog /
  // ReadTipConfig）— Cursor UI
  int headerMode;
  int footerMode;
  int tipHeaderLeft;
  int tipHeaderMiddle;
  int tipHeaderRight;
  int tipFooterLeft;
  int tipFooterMiddle;
  int tipFooterRight;
  int titleMode;
  int titleSize;
  int titleTopSpacing;
  int titleBottomSpacing;

  // 状态栏提示栏
  bool showBattery;
  bool showTime;
  bool showProgress;
  bool showChapterName;

  // [UI-fix v2.0.3 | 2026-08-08] MoreConfig 第①批无平台依赖项落地：
  // 键名对齐原版 AppConfig/PreferKey（见 MoreConfigDialog.onSharedPreferenceChanged
  // 事件语义与 pref_config_read.xml），持久化不使用 reader_adv_ 前缀 — Qoder

  /// 屏幕方向（0跟随系统 1竖屏 2横屏 3自动传感器 4反向竖屏 5反向横屏，
  /// 对标原版 screenOrientation/screen_direction_value）
  int screenOrientation;

  /// 保持亮屏时长（秒：0默认 60/300/600 -1常亮，对标原版 keep_light/screen_time_out）
  int keepLight;

  /// 隐藏状态栏（对标原版 hideStatusBar）
  bool hideStatusBar;

  /// 隐藏导航栏（对标原版 hideNavigationBar）
  bool hideNavigationBar;

  /// 进度条行为（'page'=调章内页 'chapter'=调章节，对标原版 progressBarBehavior）
  String progressBarBehavior;

  /// 滚动翻页无动画（对标原版 noAnimScrollPage）
  bool noAnimScrollPage;

  /// 自动换源：章节加载失败自动切换书源（对标原版 autoChangeSource）
  bool autoChangeSource;

  /// 长按选择文本（对标原版 selectText/textSelectAble）
  bool selectText;

  /// 亮度控件：0 关闭，1 横向，2 纵向；保存键沿用上游。
  int brightnessMode;

  /// 竖向亮度控件是否置于左侧。
  bool brightnessOnLeft;

  /// 顶栏显示标题附加区（书名后追加章名，对标原版 showReadTitleAddition）
  bool showReadTitleAddition;

  /// 菜单配色：0 跟随应用，1 从阅读背景生成，2 自定义。
  int readBarStyle;
  String readMenuPaletteStyle;
  int readMenuColorMode;
  int readMenuAccentColor;
  int readMenuAccentColorNight;
  int readMenuBgColor;
  int readMenuBgColorNight;
  int readMenuContainerColor;
  int readMenuContainerColorNight;
  int readMenuTextColor;
  int readMenuTextColorNight;

  // [UI-fix v2.0.4 | 2026-08-08] MoreConfig 第②批（键名逐项对齐原版
  // pref_config_read.xml，平台受限项仅持久化并在 UI 中诚实标注）— Qoder

  /// 音量键翻页（对标原版 volumeKeyPage；桌面端无音量键，仅 Android 生效）
  bool volumeKeyPage;

  /// 朗读时音量键翻页（对标原版 volumeKeyPageOnPlay）
  bool volumeKeyPageOnPlay;

  /// 鼠标滚轮翻页（对标原版 mouseWheelPage，桌面端真实生效）
  bool mouseWheelPage;

  /// 双页模式（0全局单页/1全局双页/2横屏双页/3平板或横屏双页，
  /// 对标原版 doubleHorizontalPage；已接入 ReaderPageView 分页/渲染）
  int doubleHorizontalPage;

  /// 使用自定义中文分行（对标原版 useZhLayout；false=朴素按宽断行）
  bool useZhLayout;

  /// 段首标点悬挂（对标原版 hangingPunctuation；已接入排版引擎）
  bool hangingPunctuation;

  /// 滑动翻页阈值（px，0=系统默认值，对标原版 pageTouchSlop）
  int pageTouchSlop;

  /// 边缘点击阈值（px，左右边缘多少距离不触发点击，对标原版 pageTouchClick）
  int pageTouchClick;

  /// 扩展到刘海（正文延伸到刘海区域，对标原版 readBodyToLh）
  bool readBodyToLh;

  /// 填充刘海区域（对标原版 paddingDisplayCutouts）
  bool paddingDisplayCutouts;

  ReaderAdvancedConfig({
    this.autoPageTurn = false,
    this.autoPageTurnInterval = 10,
    this.autoPageTurnForward = true,
    List<TapAction>? tapActions,
    this.paragraphSpacing = 2,
    this.letterSpacing = 0.1,
    this.paragraphIndent = 2,
    this.textFullJustify = true,
    this.textBold = 0,
    this.italic = false,
    this.pageMarginTop = 24,
    this.pageMarginBottom = 24,
    this.pageMarginLeft = 20,
    this.pageMarginRight = 20,
    this.headerPaddingTop = 0,
    this.headerPaddingBottom = 0,
    this.headerPaddingLeft = 16,
    this.headerPaddingRight = 16,
    this.footerPaddingTop = 6,
    this.footerPaddingBottom = 6,
    this.footerPaddingLeft = 16,
    this.footerPaddingRight = 16,
    this.showHeaderLine = false,
    this.showFooterLine = true,
    this.headerMode = 0,
    this.footerMode = 0,
    this.tipHeaderLeft = 2,
    this.tipHeaderMiddle = 0,
    this.tipHeaderRight = 3,
    // [C2 R5] 底栏左侧语义对齐参考：参考底栏左显示书名（斗罗大陆），
    // 我方原为章节名（截断）。tipFooterLeft 由 1(章节名) 改 7(书名)。
    this.tipFooterLeft = 7,
    this.tipFooterMiddle = 0,
    this.tipFooterRight = 6,
    this.titleMode = 0,
    this.titleSize = 0,
    this.titleTopSpacing = 0,
    this.titleBottomSpacing = 0,
    // [C2 R4] 顶部「时间+章节名+进度」状态行默认关闭（参考该态无此信息行；
    // 头部信息开关默认关，用户可在「阅读提示信息」面板手动开启）
    this.showBattery = false,
    this.showTime = false,
    this.showProgress = false,
    this.showChapterName = false,
    this.screenOrientation = 0,
    this.keepLight = 0,
    this.hideStatusBar = false,
    this.hideNavigationBar = false,
    this.progressBarBehavior = 'page',
    this.noAnimScrollPage = false,
    this.autoChangeSource = true,
    this.selectText = true,
    // [PARITY C2 M5] 参考阅读器菜单该态未见亮度条：默认关闭菜单内亮度行，
    // 亮度控件改为用户按需开启（设置开关保留），对齐参考紧凑浮层形态。
    this.brightnessMode = 0,
    this.brightnessOnLeft = false,
    this.showReadTitleAddition = true,
    this.readBarStyle = 0,
    this.readMenuPaletteStyle = '',
    this.readMenuColorMode = 0,
    this.readMenuAccentColor = 0,
    this.readMenuAccentColorNight = 0,
    this.readMenuBgColor = 0,
    this.readMenuBgColorNight = 0,
    this.readMenuContainerColor = 0,
    this.readMenuContainerColorNight = 0,
    this.readMenuTextColor = 0,
    this.readMenuTextColorNight = 0,
    this.volumeKeyPage = true,
    this.volumeKeyPageOnPlay = false,
    this.mouseWheelPage = true,
    this.doubleHorizontalPage = 0,
    this.useZhLayout = false,
    this.hangingPunctuation = false,
    this.pageTouchSlop = 0,
    this.pageTouchClick = 0,
    this.readBodyToLh = false,
    this.paddingDisplayCutouts = false,
  }) : tapActions = _copyTapActions(tapActions);

  /// 各区域默认边距（对标 ReadBookConfig.Config 默认值）
  static Map<PaddingRegion, Map<String, double>> regionDefaultPaddings() => {
    PaddingRegion.header: {'top': 0, 'bottom': 0, 'left': 16, 'right': 16},
    PaddingRegion.body: {'top': 6, 'bottom': 6, 'left': 16, 'right': 16},
    PaddingRegion.footer: {'top': 6, 'bottom': 6, 'left': 16, 'right': 16},
  };

  static double defaultPaddingFor(PaddingRegion region, String side) =>
      regionDefaultPaddings()[region]![side]!;

  ReaderAdvancedConfig copy() => ReaderAdvancedConfig(
    autoPageTurn: autoPageTurn,
    autoPageTurnInterval: autoPageTurnInterval,
    autoPageTurnForward: autoPageTurnForward,
    tapActions: tapActions,
    paragraphSpacing: paragraphSpacing,
    letterSpacing: letterSpacing,
    paragraphIndent: paragraphIndent,
    textFullJustify: textFullJustify,
    textBold: textBold,
    italic: italic,
    pageMarginTop: pageMarginTop,
    pageMarginBottom: pageMarginBottom,
    pageMarginLeft: pageMarginLeft,
    pageMarginRight: pageMarginRight,
    headerPaddingTop: headerPaddingTop,
    headerPaddingBottom: headerPaddingBottom,
    headerPaddingLeft: headerPaddingLeft,
    headerPaddingRight: headerPaddingRight,
    footerPaddingTop: footerPaddingTop,
    footerPaddingBottom: footerPaddingBottom,
    footerPaddingLeft: footerPaddingLeft,
    footerPaddingRight: footerPaddingRight,
    showHeaderLine: showHeaderLine,
    showFooterLine: showFooterLine,
    headerMode: headerMode,
    footerMode: footerMode,
    tipHeaderLeft: tipHeaderLeft,
    tipHeaderMiddle: tipHeaderMiddle,
    tipHeaderRight: tipHeaderRight,
    tipFooterLeft: tipFooterLeft,
    tipFooterMiddle: tipFooterMiddle,
    tipFooterRight: tipFooterRight,
    titleMode: titleMode,
    titleSize: titleSize,
    titleTopSpacing: titleTopSpacing,
    titleBottomSpacing: titleBottomSpacing,
    showBattery: showBattery,
    showTime: showTime,
    showProgress: showProgress,
    showChapterName: showChapterName,
    screenOrientation: screenOrientation,
    keepLight: keepLight,
    hideStatusBar: hideStatusBar,
    hideNavigationBar: hideNavigationBar,
    progressBarBehavior: progressBarBehavior,
    noAnimScrollPage: noAnimScrollPage,
    autoChangeSource: autoChangeSource,
    selectText: selectText,
    brightnessMode: brightnessMode,
    brightnessOnLeft: brightnessOnLeft,
    showReadTitleAddition: showReadTitleAddition,
    readBarStyle: readBarStyle,
    readMenuPaletteStyle: readMenuPaletteStyle,
    readMenuColorMode: readMenuColorMode,
    readMenuAccentColor: readMenuAccentColor,
    readMenuAccentColorNight: readMenuAccentColorNight,
    readMenuBgColor: readMenuBgColor,
    readMenuBgColorNight: readMenuBgColorNight,
    readMenuContainerColor: readMenuContainerColor,
    readMenuContainerColorNight: readMenuContainerColorNight,
    readMenuTextColor: readMenuTextColor,
    readMenuTextColorNight: readMenuTextColorNight,
    volumeKeyPage: volumeKeyPage,
    volumeKeyPageOnPlay: volumeKeyPageOnPlay,
    mouseWheelPage: mouseWheelPage,
    doubleHorizontalPage: doubleHorizontalPage,
    useZhLayout: useZhLayout,
    hangingPunctuation: hangingPunctuation,
    pageTouchSlop: pageTouchSlop,
    pageTouchClick: pageTouchClick,
    readBodyToLh: readBodyToLh,
    paddingDisplayCutouts: paddingDisplayCutouts,
  );
}
