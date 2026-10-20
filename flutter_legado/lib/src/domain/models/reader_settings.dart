import 'page_turn_mode.dart';
import 'reader_text_layout_settings.dart';
import 'reader_page_layout_settings.dart';
import 'reader_screen_settings.dart';
import 'reader_status_strip_settings.dart';
import 'reader_auto_page_turn_settings.dart';
import 'reader_interaction_settings.dart';
import 'reader_menu_theme_settings.dart';
import 'reader_brightness_control_settings.dart';

/// 阅读普通偏好的共享投影；存储键、默认值和单位由仓储统一解释。— Codex + UI
final class ReaderSettings {
  const ReaderSettings({
    this.pageTurnMode = PageTurnMode.cover,
    this.fontSize = 20.0,
    this.lineHeight = 1.7,
    this.fontFamily,
    this.titleFontFamily = '',
    this.tocLoadWordCount = true,
    this.chapterInSystemBrowser = false,
    this.autoChangeSource = true,
    this.showTitleAddition = true,
    this.textLayout = const ReaderTextLayoutSettings(),
    this.pageLayout = const ReaderPageLayoutSettings(),
    this.screen = const ReaderScreenSettings(),
    this.statusStrip = const ReaderStatusStripSettings(),
    this.autoPageTurn = const ReaderAutoPageTurnSettings(),
    this.interaction = const ReaderInteractionSettings.defaults(),
    this.menuTheme = const ReaderMenuThemeSettings(),
    this.brightnessControl = const ReaderBrightnessControlSettings(),
  });

  final PageTurnMode pageTurnMode;
  final double fontSize;
  final double lineHeight;
  final String? fontFamily;
  final String titleFontFamily;
  final bool tocLoadWordCount;
  final bool chapterInSystemBrowser;
  final bool autoChangeSource;

  /// 顶栏标题附加区尚未启用，仅保留设置定义。
  final bool showTitleAddition;
  final ReaderTextLayoutSettings textLayout;
  final ReaderPageLayoutSettings pageLayout;
  final ReaderScreenSettings screen;
  final ReaderStatusStripSettings statusStrip;
  final ReaderAutoPageTurnSettings autoPageTurn;
  final ReaderInteractionSettings interaction;
  final ReaderMenuThemeSettings menuTheme;
  final ReaderBrightnessControlSettings brightnessControl;

  @override
  bool operator ==(Object other) =>
      other is ReaderSettings &&
      pageTurnMode == other.pageTurnMode &&
      fontSize == other.fontSize &&
      lineHeight == other.lineHeight &&
      fontFamily == other.fontFamily &&
      titleFontFamily == other.titleFontFamily &&
      tocLoadWordCount == other.tocLoadWordCount &&
      chapterInSystemBrowser == other.chapterInSystemBrowser &&
      autoChangeSource == other.autoChangeSource &&
      showTitleAddition == other.showTitleAddition &&
      textLayout == other.textLayout &&
      pageLayout == other.pageLayout &&
      screen == other.screen &&
      statusStrip == other.statusStrip &&
      autoPageTurn == other.autoPageTurn &&
      interaction == other.interaction &&
      menuTheme == other.menuTheme &&
      brightnessControl == other.brightnessControl;

  @override
  int get hashCode => Object.hash(
    pageTurnMode,
    fontSize,
    lineHeight,
    fontFamily,
    titleFontFamily,
    tocLoadWordCount,
    chapterInSystemBrowser,
    autoChangeSource,
    showTitleAddition,
    textLayout,
    pageLayout,
    screen,
    statusStrip,
    autoPageTurn,
    interaction,
    menuTheme,
    brightnessControl,
  );
}
