import '../../models/reader_advanced_config.dart';

import 'package:material_ui/material_ui.dart';

import '../../providers/ui_settings/ui_settings_notifier.dart';
import '../../theme/app_theme.dart';
import '../../theme/md3_colors.dart';
import '../../theme/theme_engine_parameterized.dart';
import '../ui_settings_scope.dart';

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

/// 阅读页面共用的菜单主题入口；正文仍继承应用主题，弹层使用独立的稳定上下文。
class ReaderMenuThemeHost extends StatefulWidget {
  const ReaderMenuThemeHost({
    super.key,
    required this.config,
    required this.readingBackground,
    required this.builder,
  });

  final ReaderAdvancedConfig config;
  final Color readingBackground;
  final WidgetBuilder builder;

  @override
  State<ReaderMenuThemeHost> createState() => _ReaderMenuThemeHostState();
}

class _ReaderMenuThemeHostState extends State<ReaderMenuThemeHost> {
  Object? _key;
  ThemeData? _theme;

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context);
    final ui = UiSettingsScope.of(context, UiSettingsAspect.readerTheme);
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
      child: Builder(
        builder: (menuContext) => _ReaderMenuThemeScope(
          theme: _theme!,
          menuContext: menuContext,
          // 正文和分页保留原主题；只有菜单及其浮层消费菜单主题。
          child: Theme(
            data: appTheme,
            child: Builder(builder: widget.builder),
          ),
        ),
      ),
    );
  }
}

class _ReaderMenuThemeScope extends InheritedWidget {
  const _ReaderMenuThemeScope({
    required this.theme,
    required this.menuContext,
    required super.child,
  });

  final ThemeData theme;
  final BuildContext menuContext;

  @override
  bool updateShouldNotify(_ReaderMenuThemeScope oldWidget) =>
      theme != oldWidget.theme || menuContext != oldWidget.menuContext;
}

/// 页面存活期间可用于导航和弹层，选区浮窗销毁后仍可使用。
BuildContext readerMenuContextOf(BuildContext context) =>
    context
        .dependOnInheritedWidgetOfExactType<_ReaderMenuThemeScope>()
        ?.menuContext ??
    context;

/// 将同一菜单主题应用到菜单分支，不改变正文主题。
class ReaderMenuTheme extends StatelessWidget {
  const ReaderMenuTheme({super.key, required this.builder});

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(readerMenuContextOf(context)),
    child: Builder(builder: builder),
  );
}
