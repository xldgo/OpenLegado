/// 日夜主题中的颜色槽位，与存储键及 Flutter 绘制类型无关。— Codex + UI
enum ThemeColorRole {
  primary,
  accent,
  background,
  bottomBackground,
  primaryNight,
  accentNight,
  backgroundNight,
  bottomBackgroundNight,
}

/// null 使用默认颜色，空路径表示未配置背景图。— Codex + UI
final class ThemeColorsSettings {
  const ThemeColorsSettings({
    this.primary,
    this.accent,
    this.background,
    this.bottomBackground,
    this.primaryNight,
    this.accentNight,
    this.backgroundNight,
    this.bottomBackgroundNight,
    this.bgImage = '',
    this.bgImageNight = '',
  });

  final int? primary;
  final int? accent;
  final int? background;
  final int? bottomBackground;
  final int? primaryNight;
  final int? accentNight;
  final int? backgroundNight;
  final int? bottomBackgroundNight;
  final String bgImage;
  final String bgImageNight;

  int? color(ThemeColorRole role) => switch (role) {
    ThemeColorRole.primary => primary,
    ThemeColorRole.accent => accent,
    ThemeColorRole.background => background,
    ThemeColorRole.bottomBackground => bottomBackground,
    ThemeColorRole.primaryNight => primaryNight,
    ThemeColorRole.accentNight => accentNight,
    ThemeColorRole.backgroundNight => backgroundNight,
    ThemeColorRole.bottomBackgroundNight => bottomBackgroundNight,
  };

  String bgImageFor({required bool isNight}) =>
      isNight ? bgImageNight : bgImage;

  @override
  bool operator ==(Object other) =>
      other is ThemeColorsSettings &&
      primary == other.primary &&
      accent == other.accent &&
      background == other.background &&
      bottomBackground == other.bottomBackground &&
      primaryNight == other.primaryNight &&
      accentNight == other.accentNight &&
      backgroundNight == other.backgroundNight &&
      bottomBackgroundNight == other.bottomBackgroundNight &&
      bgImage == other.bgImage &&
      bgImageNight == other.bgImageNight;

  @override
  int get hashCode => Object.hash(
    primary,
    accent,
    background,
    bottomBackground,
    primaryNight,
    accentNight,
    backgroundNight,
    bottomBackgroundNight,
    bgImage,
    bgImageNight,
  );
}
