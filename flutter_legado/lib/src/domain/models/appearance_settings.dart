/// 全局外观普通偏好，不依赖界面组件或存储实现。— Codex + UI
enum AppThemeMode { system, light, dark }

final class AppearanceSettings {
  /// 系统动态取色与内置配色共用同一选择，不叠加独立开关。
  static const dynamicPaletteId = 'dynamic';

  const AppearanceSettings({
    this.themeMode = AppThemeMode.system,
    this.fontScaleRaw = 0,
    this.paletteId = 'def',
    this.launcherIcon = 'iconMain',
  });

  final AppThemeMode themeMode;
  final int fontScaleRaw;
  final String paletteId;
  final String launcherIcon;

  AppearanceSettings copyWith({
    AppThemeMode? themeMode,
    int? fontScaleRaw,
    String? paletteId,
    String? launcherIcon,
  }) => AppearanceSettings(
    themeMode: themeMode ?? this.themeMode,
    fontScaleRaw: fontScaleRaw ?? this.fontScaleRaw,
    paletteId: paletteId ?? this.paletteId,
    launcherIcon: launcherIcon ?? this.launcherIcon,
  );

  @override
  bool operator ==(Object other) =>
      other is AppearanceSettings &&
      themeMode == other.themeMode &&
      fontScaleRaw == other.fontScaleRaw &&
      paletteId == other.paletteId &&
      launcherIcon == other.launcherIcon;

  @override
  int get hashCode =>
      Object.hash(themeMode, fontScaleRaw, paletteId, launcherIcon);
}
