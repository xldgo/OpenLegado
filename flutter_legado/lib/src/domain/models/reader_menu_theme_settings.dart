/// 阅读菜单配色；颜色为ARGB整数，零值沿用当前主题的回退规则。— Codex + UI
final class ReaderMenuThemeSettings {
  const ReaderMenuThemeSettings({
    this.mode = 0,
    this.paletteStyle = '',
    this.colorMode = 0,
    this.accentColor = 0,
    this.accentColorNight = 0,
    this.backgroundColor = 0,
    this.backgroundColorNight = 0,
    this.containerColor = 0,
    this.containerColorNight = 0,
    this.textColor = 0,
    this.textColorNight = 0,
  });

  /// 0跟随应用，1从阅读背景生成，2自定义。
  final int mode;
  final String paletteStyle;

  /// 0种子生成，1手动设置表面颜色。
  final int colorMode;
  final int accentColor;
  final int accentColorNight;
  final int backgroundColor;
  final int backgroundColorNight;
  final int containerColor;
  final int containerColorNight;
  final int textColor;
  final int textColorNight;

  @override
  bool operator ==(Object other) =>
      other is ReaderMenuThemeSettings &&
      mode == other.mode &&
      paletteStyle == other.paletteStyle &&
      colorMode == other.colorMode &&
      accentColor == other.accentColor &&
      accentColorNight == other.accentColorNight &&
      backgroundColor == other.backgroundColor &&
      backgroundColorNight == other.backgroundColorNight &&
      containerColor == other.containerColor &&
      containerColorNight == other.containerColorNight &&
      textColor == other.textColor &&
      textColorNight == other.textColorNight;

  @override
  int get hashCode => Object.hash(
    mode,
    paletteStyle,
    colorMode,
    accentColor,
    accentColorNight,
    backgroundColor,
    backgroundColorNight,
    containerColor,
    containerColorNight,
    textColor,
    textColorNight,
  );
}
