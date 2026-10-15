import '../../domain/models/app_settings_snapshot.dart';
import '../../domain/models/reader_menu_theme_settings.dart';
import '../../domain/models/reader_brightness_control_settings.dart';

/// 菜单配色和亮度控件的规范键与类型映射，不执行IO。— Codex + UI
final class ReaderMenuSettingsCodec {
  const ReaderMenuSettingsCodec();

  static const _keys = [
    'menu_theme_mode',
    'menu_palette_style',
    'menu_color_mode',
    'menu_accent_color',
    'menu_accent_color_night',
    'menu_background_color',
    'menu_background_color_night',
    'menu_container_color',
    'menu_container_color_night',
    'menu_text_color',
    'menu_text_color_night',
    'brightness_control_mode',
    'brightness_control_on_left',
  ];

  static SettingsAddress _address(String key) =>
      (storage: SettingsStorageKind.preferences, key: 'reader_$key');

  Set<SettingsAddress> get addresses => {
    for (final key in _keys) _address(key),
  };

  int _int(AppSettingsSnapshot snapshot, String key, int max) =>
      (snapshot[_address(key)] is int ? snapshot[_address(key)] as int : 0)
          .clamp(0, max);

  ReaderMenuThemeSettings decodeTheme(AppSettingsSnapshot snapshot) =>
      ReaderMenuThemeSettings(
        mode: _int(snapshot, 'menu_theme_mode', 2),
        paletteStyle: snapshot[_address('menu_palette_style')] is String
            ? snapshot[_address('menu_palette_style')] as String
            : '',
        colorMode: _int(snapshot, 'menu_color_mode', 1),
        accentColor: _int(snapshot, 'menu_accent_color', 0xffffffff),
        accentColorNight: _int(snapshot, 'menu_accent_color_night', 0xffffffff),
        backgroundColor: _int(snapshot, 'menu_background_color', 0xffffffff),
        backgroundColorNight: _int(
          snapshot,
          'menu_background_color_night',
          0xffffffff,
        ),
        containerColor: _int(snapshot, 'menu_container_color', 0xffffffff),
        containerColorNight: _int(
          snapshot,
          'menu_container_color_night',
          0xffffffff,
        ),
        textColor: _int(snapshot, 'menu_text_color', 0xffffffff),
        textColorNight: _int(snapshot, 'menu_text_color_night', 0xffffffff),
      );

  ReaderBrightnessControlSettings decodeBrightnessControl(
    AppSettingsSnapshot snapshot,
  ) => ReaderBrightnessControlSettings(
    mode: _int(snapshot, 'brightness_control_mode', 2),
    onLeft: snapshot[_address('brightness_control_on_left')] == true,
  );

  Map<SettingsAddress, Object?> themePatch({
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
  }) => {
    _address('menu_theme_mode'): ?mode?.clamp(0, 2),
    _address('menu_palette_style'): ?paletteStyle,
    _address('menu_color_mode'): ?colorMode?.clamp(0, 1),
    _address('menu_accent_color'): ?accentColor?.clamp(0, 0xffffffff),
    _address('menu_accent_color_night'): ?accentColorNight?.clamp(
      0,
      0xffffffff,
    ),
    _address('menu_background_color'): ?backgroundColor?.clamp(0, 0xffffffff),
    _address('menu_background_color_night'): ?backgroundColorNight?.clamp(
      0,
      0xffffffff,
    ),
    _address('menu_container_color'): ?containerColor?.clamp(0, 0xffffffff),
    _address('menu_container_color_night'): ?containerColorNight?.clamp(
      0,
      0xffffffff,
    ),
    _address('menu_text_color'): ?textColor?.clamp(0, 0xffffffff),
    _address('menu_text_color_night'): ?textColorNight?.clamp(0, 0xffffffff),
  };

  Map<SettingsAddress, Object?> brightnessControlPatch({
    int? mode,
    bool? onLeft,
  }) => {
    _address('brightness_control_mode'): ?mode?.clamp(0, 2),
    _address('brightness_control_on_left'): ?onLeft,
  };
}
