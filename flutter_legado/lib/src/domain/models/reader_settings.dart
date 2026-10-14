import 'page_turn_mode.dart';

/// 阅读普通偏好的共享投影；原键、默认值和单位由仓储统一解释。— Codex + UI
final class ReaderSettings {
  const ReaderSettings({
    this.pageTurnMode = PageTurnMode.cover,
    this.fontSize = 20.0,
    this.lineHeight = 1.7,
    this.fontFamily,
    this.titleFontFamily = '',
  });

  final PageTurnMode pageTurnMode;
  final double fontSize;
  final double lineHeight;
  final String? fontFamily;
  final String titleFontFamily;

  @override
  bool operator ==(Object other) =>
      other is ReaderSettings &&
      pageTurnMode == other.pageTurnMode &&
      fontSize == other.fontSize &&
      lineHeight == other.lineHeight &&
      fontFamily == other.fontFamily &&
      titleFontFamily == other.titleFontFamily;

  @override
  int get hashCode => Object.hash(
    pageTurnMode,
    fontSize,
    lineHeight,
    fontFamily,
    titleFontFamily,
  );
}
