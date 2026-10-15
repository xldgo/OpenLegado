/// 正文点击区域动作，不依赖Flutter几何类型。— Codex + UI
enum TapAction {
  none,
  prevPage,
  nextPage,
  toggleControls,
  openCatalog;

  String get label => switch (this) {
    none => '无操作',
    prevPage => '上一页/章',
    nextPage => '下一页/章',
    toggleControls => '切换工具栏',
    openCatalog => '打开目录',
  };
}

/// 操作偏好与不可变九宫格，命中计算和手势执行由界面层负责。
final class ReaderInteractionSettings {
  ReaderInteractionSettings({
    List<TapAction> tapActions = defaultTapActions,
    this.selectText = true,
    this.noAnimScrollPage = false,
    this.volumeKeyPage = true,
    this.volumeKeyPageOnPlay = false,
    this.mouseWheelPage = true,
    this.pageTouchSlop = 0,
    this.pageTouchClick = 0,
    this.progressBarBehavior = 'page',
  }) : tapActions = _copyActions(tapActions);

  const ReaderInteractionSettings.defaults()
    : tapActions = defaultTapActions,
      selectText = true,
      noAnimScrollPage = false,
      volumeKeyPage = true,
      volumeKeyPageOnPlay = false,
      mouseWheelPage = true,
      pageTouchSlop = 0,
      pageTouchClick = 0,
      progressBarBehavior = 'page';

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
  final bool selectText;
  final bool noAnimScrollPage;
  final bool volumeKeyPage;
  final bool volumeKeyPageOnPlay;
  final bool mouseWheelPage;
  final int pageTouchSlop;
  final int pageTouchClick;
  final String progressBarBehavior;

  static List<TapAction> _copyActions(List<TapAction> actions) {
    if (actions.length != 9) {
      throw ArgumentError.value(actions.length, 'tapActions', '必须包含九个区域');
    }
    return List.unmodifiable(actions);
  }

  @override
  bool operator ==(Object other) =>
      other is ReaderInteractionSettings &&
      tapActions.indexed.every(
        (entry) => entry.$2 == other.tapActions[entry.$1],
      ) &&
      selectText == other.selectText &&
      noAnimScrollPage == other.noAnimScrollPage &&
      volumeKeyPage == other.volumeKeyPage &&
      volumeKeyPageOnPlay == other.volumeKeyPageOnPlay &&
      mouseWheelPage == other.mouseWheelPage &&
      pageTouchSlop == other.pageTouchSlop &&
      pageTouchClick == other.pageTouchClick &&
      progressBarBehavior == other.progressBarBehavior;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(tapActions),
    selectText,
    noAnimScrollPage,
    volumeKeyPage,
    volumeKeyPageOnPlay,
    mouseWheelPage,
    pageTouchSlop,
    pageTouchClick,
    progressBarBehavior,
  );
}
