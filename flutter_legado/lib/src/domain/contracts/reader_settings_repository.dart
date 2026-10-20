import '../models/reader_settings.dart';
import '../models/page_turn_mode.dart';
import '../models/reader_page_layout_settings.dart';
import '../models/reader_interaction_settings.dart';

/// 阅读普通偏好同源访问，按字段更新并订阅共享快照。— Codex + UI
abstract interface class ReaderSettingsRepository {
  ReaderSettings get current;
  Stream<ReaderSettings> watch();
  Future<ReaderSettings> load();
  Future<void> reload();

  /// 未传字段不变；正文字体空串删除选择，标题空串跟随正文。
  Future<void> update({
    PageTurnMode? pageTurnMode,
    double? fontSize,
    double? lineHeight,
    String? fontFamily,
    String? titleFontFamily,
    bool? tocLoadWordCount,
    bool? chapterInSystemBrowser,
    bool? autoChangeSource,
    bool? showTitleAddition,
    bool? showMenuLabels,
  });

  /// 只修改传入的正文排版字段，不保存其他页面的旧快照。
  Future<void> updateTextLayout({
    double? paragraphSpacing,
    double? letterSpacing,
    int? paragraphIndent,
    bool? textFullJustify,
    int? textBold,
    bool? italic,
    bool? useZhLayout,
    bool? hangingPunctuation,
  });
  Future<void> updatePageLayout({
    double? top,
    double? bottom,
    double? left,
    double? right,
    int? doubleHorizontalPage,
  });
  Future<void> updatePageEdge(
    ReaderPageEdge edge, {
    double? top,
    double? bottom,
    double? left,
    double? right,
    int? mode,
    bool? showLine,
    int? leftTip,
    int? middleTip,
    int? rightTip,
  });
  Future<void> updateTitle({
    int? mode,
    int? size,
    int? topSpacing,
    int? bottomSpacing,
  });
  Future<void> updateScreen({
    int? orientation,
    int? keepScreenOnSeconds,
    bool? hideStatusBar,
    bool? hideNavigationBar,
    bool? extendIntoCutout,
    bool? avoidDisplayCutouts,
  });
  Future<void> updateStatusStrip({
    bool? showBattery,
    bool? showTime,
    bool? showProgress,
    bool? showChapterName,
  });
  Future<void> updateAutoPageTurn({
    bool? enabled,
    double? intervalSeconds,
    bool? forward,
  });
  Future<void> updateInteraction({
    List<TapAction>? tapActions,
    bool? selectText,
    bool? noAnimScrollPage,
    bool? volumeKeyPage,
    bool? volumeKeyPageOnPlay,
    bool? mouseWheelPage,
    int? pageTouchSlop,
    int? pageTouchClick,
    String? progressBarBehavior,
  });
  Future<void> updateMenuTheme({
    int? mode,
    String? paletteStyle,
    int? colorMode,
    int? accentColor,
    int? accentColorNight,
    int? backgroundColor,
    int? backgroundColorNight,
    int? containerColor,
    int? containerColorNight,
    int? textColor,
    int? textColorNight,
  });
  Future<void> updateBrightnessControl({int? mode, bool? onLeft});
}
