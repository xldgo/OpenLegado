/// 正文排版规则的不可变快照；不依赖平台文字测量。— Codex + UI
final class ReaderTextLayoutSettings {
  const ReaderTextLayoutSettings({
    this.paragraphSpacing = 2,
    this.letterSpacing = 0,
    this.paragraphIndent = 2,
    this.textFullJustify = true,
    this.textBottomJustify = true,
    this.textBold = 0,
    this.italic = false,
    this.useZhLayout = true,
    this.hangingPunctuation = false,
  });

  /// 段距为自然行高的十分之一刻度（2=0.2倍）；字距为em，缩进为字符数。
  final double paragraphSpacing;
  final double letterSpacing;
  final int paragraphIndent;
  final bool textFullJustify;
  final bool textBottomJustify;

  /// 0常规、1粗体、2细体，沿用现有控件与渲染语义。
  final int textBold;
  final bool italic;
  final bool useZhLayout;
  final bool hangingPunctuation;

  @override
  bool operator ==(Object other) =>
      other is ReaderTextLayoutSettings &&
      paragraphSpacing == other.paragraphSpacing &&
      letterSpacing == other.letterSpacing &&
      paragraphIndent == other.paragraphIndent &&
      textFullJustify == other.textFullJustify &&
      textBottomJustify == other.textBottomJustify &&
      textBold == other.textBold &&
      italic == other.italic &&
      useZhLayout == other.useZhLayout &&
      hangingPunctuation == other.hangingPunctuation;

  @override
  int get hashCode => Object.hash(
    paragraphSpacing,
    letterSpacing,
    paragraphIndent,
    textFullJustify,
    textBottomJustify,
    textBold,
    italic,
    useZhLayout,
    hangingPunctuation,
  );
}
