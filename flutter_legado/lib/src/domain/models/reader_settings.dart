import 'page_turn_mode.dart';
import 'reader_text_layout_settings.dart';

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
    this.textLayout = const ReaderTextLayoutSettings(),
  });

  final PageTurnMode pageTurnMode;
  final double fontSize;
  final double lineHeight;
  final String? fontFamily;
  final String titleFontFamily;
  final bool tocLoadWordCount;
  final bool chapterInSystemBrowser;
  final ReaderTextLayoutSettings textLayout;

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
      textLayout == other.textLayout;

  @override
  int get hashCode => Object.hash(
    pageTurnMode,
    fontSize,
    lineHeight,
    fontFamily,
    titleFontFamily,
    tocLoadWordCount,
    chapterInSystemBrowser,
    textLayout,
  );
}
