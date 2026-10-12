import 'package:material_ui/material_ui.dart';

import '../../providers/ui_settings/ui_settings_notifier.dart';
import '../../screens/reader_config_panel.dart';
import '../../theme/app_theme.dart';
import '../../theme/md3_colors.dart';
import '../../theme/theme_engine_parameterized.dart';

/// 对齐上游 ReadBookColorTheme：正文背景作为种子，菜单仍使用完整的颜色角色。
ThemeData resolveReaderMenuTheme({
  required ThemeData appTheme,
  required Color readingBackground,
  required ReaderAdvancedConfig config,
  required UiSettingsState ui,
}) {
  if (config.readBarStyle == 0) return appTheme;
  final night = appTheme.brightness == Brightness.dark;
  final storedAccent = night
      ? config.readMenuAccentColorNight
      : config.readMenuAccentColor;
  final accent = storedAccent == 0
      ? appTheme.colorScheme.primary
      : Color(storedAccent);
  final seed = config.readBarStyle == 1 ? readingBackground : accent;
  final style = config.readMenuPaletteStyle.isNotEmpty
      ? config.readMenuPaletteStyle
      : ui.themeStyle == 'none'
      ? 'tonalSpot'
      : ui.themeStyle;
  final roles = buildParameterizedRoles(
    style: style,
    seed: seed.toARGB32(),
    contrastLevel: double.tryParse(ui.themeContrastLevel) ?? 0,
  );
  final palette = Md3Palette(
    id: 'reader-menu',
    label: '阅读菜单',
    seed: seed.toARGB32(),
    light: roles.light,
    dark: roles.dark,
  );
  var scheme = night ? md3DarkScheme(palette) : md3LightScheme(palette);
  if (config.readBarStyle == 2 && config.readMenuColorMode != 0) {
    final backgroundValue = night
        ? config.readMenuBgColorNight
        : config.readMenuBgColor;
    final background = backgroundValue == 0
        ? readingBackground
        : Color(backgroundValue);
    final containerValue = night
        ? config.readMenuContainerColorNight
        : config.readMenuContainerColor;
    final container = containerValue == 0 ? background : Color(containerValue);
    scheme = scheme.copyWith(
      primary: accent,
      onPrimary: accent.computeLuminance() > 0.5 ? Colors.black : Colors.white,
      surfaceTint: accent,
      surfaceContainerHigh: background,
      surfaceContainerLow: container,
    );
  }
  return AppTheme.withColorScheme(appTheme, scheme);
}

/// 主题只覆盖菜单和阅读弹层，不进入正文分页树；颜色不变时复用装配结果。
class ReaderMenuTheme extends StatefulWidget {
  const ReaderMenuTheme({
    super.key,
    required this.config,
    required this.readingBackground,
    required this.builder,
  });

  final ReaderAdvancedConfig config;
  final Color readingBackground;
  final WidgetBuilder builder;

  @override
  State<ReaderMenuTheme> createState() => _ReaderMenuThemeState();
}

class _ReaderMenuThemeState extends State<ReaderMenuTheme> {
  Object? _key;
  ThemeData? _theme;

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context);
    return ValueListenableBuilder<UiSettingsState>(
      valueListenable: uiSettingsListenable,
      builder: (context, ui, _) {
        final config = widget.config;
        final key = (
          appTheme,
          widget.readingBackground,
          config.readBarStyle,
          config.readMenuPaletteStyle,
          config.readMenuColorMode,
          config.readMenuAccentColor,
          config.readMenuAccentColorNight,
          config.readMenuBgColor,
          config.readMenuBgColorNight,
          config.readMenuContainerColor,
          config.readMenuContainerColorNight,
          ui.themeStyle,
          ui.themeContrastLevel,
        );
        if (_key != key) {
          _key = key;
          _theme = resolveReaderMenuTheme(
            appTheme: appTheme,
            readingBackground: widget.readingBackground,
            config: config,
            ui: ui,
          );
        }
        return Theme(
          data: _theme!,
          child: Builder(builder: widget.builder),
        );
      },
    );
  }
}
