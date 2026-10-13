/// 主题文件中的一组颜色，null 表示清除该项自定义值。
class ThemeDocumentColors {
  const ThemeDocumentColors({
    this.primary,
    this.accent,
    this.background,
    this.bottomBackground,
  });

  factory ThemeDocumentColors.fromJson(Object? value) {
    final json = value is Map<String, dynamic>
        ? value
        : const <String, dynamic>{};
    int? color(String key) {
      final value = json[key];
      return value is num ? value.toInt() : null;
    }

    return ThemeDocumentColors(
      primary: color('primary'),
      accent: color('accent'),
      background: color('background'),
      bottomBackground: color('bottomBackground'),
    );
  }

  final int? primary;
  final int? accent;
  final int? background;
  final int? bottomBackground;

  Map<String, int?> toJson() => {
    'primary': primary,
    'accent': accent,
    'background': background,
    'bottomBackground': bottomBackground,
  };
}

/// 日夜主题文件；导入沿用现有宽松规则，不校验导出的元信息声明。
class ThemeDocument {
  const ThemeDocument({
    this.paletteId,
    this.themeMode,
    this.day = const ThemeDocumentColors(),
    this.night = const ThemeDocumentColors(),
  });

  factory ThemeDocument.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('主题文件格式不正确');
    }
    final palette = value['paletteId'];
    final mode = value['themeMode'];
    return ThemeDocument(
      paletteId: palette is String && palette.isNotEmpty ? palette : null,
      themeMode: mode == 'light' || mode == 'dark' || mode == 'system'
          ? mode as String
          : null,
      day: ThemeDocumentColors.fromJson(value['day']),
      night: ThemeDocumentColors.fromJson(value['night']),
    );
  }

  final String? paletteId;
  final String? themeMode;
  final ThemeDocumentColors day;
  final ThemeDocumentColors night;

  Map<String, dynamic> toJson() => {
    'app': 'legado',
    'type': 'theme',
    'version': 1,
    'paletteId': paletteId,
    'themeMode': themeMode,
    'day': day.toJson(),
    'night': night.toJson(),
  };
}
