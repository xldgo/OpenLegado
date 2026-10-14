/// 全局外观普通偏好，不依赖界面组件或存储实现。— Codex + UI
enum AppThemeMode { system, light, dark }

final class AppearanceSettings {
  const AppearanceSettings({
    this.themeMode = AppThemeMode.system,
    this.fontScaleRaw = 0,
    this.paletteId = 'def',
  });

  final AppThemeMode themeMode;
  final int fontScaleRaw;
  final String paletteId;

  AppearanceSettings copyWith({
    AppThemeMode? themeMode,
    int? fontScaleRaw,
    String? paletteId,
  }) => AppearanceSettings(
    themeMode: themeMode ?? this.themeMode,
    fontScaleRaw: fontScaleRaw ?? this.fontScaleRaw,
    paletteId: paletteId ?? this.paletteId,
  );

  @override
  bool operator ==(Object other) =>
      other is AppearanceSettings &&
      themeMode == other.themeMode &&
      fontScaleRaw == other.fontScaleRaw &&
      paletteId == other.paletteId;

  @override
  int get hashCode => Object.hash(themeMode, fontScaleRaw, paletteId);
}
