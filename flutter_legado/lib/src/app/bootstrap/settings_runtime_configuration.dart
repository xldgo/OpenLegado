import 'dart:ui' show Brightness, Color, PlatformDispatcher;

import '../../data/repositories/app_appearance_settings_repository.dart';
import '../../data/repositories/app_reader_style_repository.dart';
import '../../data/repositories/app_reader_settings_repository.dart';
import '../../data/repositories/app_ui_settings_repository.dart';
import '../../data/services/app_settings_service.dart';
import '../../domain/contracts/reader_style_repository.dart';
import '../../domain/contracts/reader_settings_repository.dart';
import '../../domain/contracts/ui_settings_repository.dart';
import '../session/reader_theme_session.dart';
import '../../domain/contracts/appearance_settings_repository.dart';
import '../../domain/models/appearance_settings.dart';
import '../../data/bridge/runtime_configuration.dart';
import '../../theme/md3_colors.dart';
import 'app_settings_factory.dart';

/// 设置层把主题对象转成书源原有的数据协议。— Codex + UI
class SettingsRuntimeConfiguration implements RuntimeConfigurationSource {
  factory SettingsRuntimeConfiguration({
    ReaderSettingsRepository? readerSettings,
    AppearanceSettingsRepository? appearance,
    AppSettingsService? appSettings,
    ReaderThemeSession? readingSession,
    ReaderStyleRepository? readerStyles,
    UiSettingsRepository? ui,
  }) {
    final service = appSettings ?? createAppSettingsService();
    return SettingsRuntimeConfiguration._(
      readerSettings ?? AppReaderSettingsRepository(service),
      appearance ?? AppAppearanceSettingsRepository(service),
      readingSession ?? ReaderThemeSession(),
      readerStyles ?? AppReaderStyleRepository(service),
      ui ?? AppUiSettingsRepository(service),
    );
  }
  SettingsRuntimeConfiguration._(
    this._readerSettings,
    this._appearance,
    this._readingSession,
    this._readerStyles,
    this._ui,
  );
  final ReaderSettingsRepository _readerSettings;
  final AppearanceSettingsRepository _appearance;
  final ReaderThemeSession _readingSession;
  final ReaderStyleRepository _readerStyles;
  final UiSettingsRepository _ui;

  @override
  Future<RuntimeConfigSnapshot> readThemeConfig() async {
    final palette = Md3Palettes.byId((await _appearance.load()).paletteId);
    final roles = palette.light;
    String hex(int argb) =>
        '#${argb.toRadixString(16).padLeft(8, '0').toUpperCase()}';
    // 此次只迁移职责，继续使用亮色角色和原字段，包含夜间主题设置时的原取值。
    return RuntimeConfigSnapshot({
      'themeName': palette.label,
      'isNightTheme': false,
      'primaryColor': hex(roles.primary),
      'accentColor': hex(roles.secondary),
      'backgroundColor': hex(roles.surface),
      'bottomBackground': hex(roles.surfaceContainer),
      'statusBarColor': hex(roles.primary),
      'navigationBarColor': hex(roles.surface),
    });
  }

  @override
  Future<String> readThemeMode() async =>
      switch ((await _appearance.load()).themeMode) {
        AppThemeMode.light => '1',
        AppThemeMode.dark => '2',
        AppThemeMode.system => '0',
      };

  @override
  Future<RuntimeConfigSnapshot> readReadBookConfig() async {
    final settings = await _readerSettings.load();
    final styles = await _readerStyles.load();
    final appearance = await _appearance.load();
    final ui = await _ui.load();
    final night =
        _readingSession.isNightOverride ??
        switch (appearance.themeMode) {
          AppThemeMode.light => false,
          AppThemeMode.dark => true,
          AppThemeMode.system =>
            PlatformDispatcher.instance.platformBrightness == Brightness.dark,
        };
    final colors = styles.selected.colors(night);
    final resolved = colors.resolve(isNight: night, amoled: ui.themeAmoled);
    final background = resolved.background;
    final foreground = resolved.text;
    String rgb(int value) =>
        '#${(value & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
    return RuntimeConfigSnapshot({
      'name': styles.selected.name,
      'bgStr': rgb(background),
      'bgType': 0,
      'textColor': rgb(foreground),
      'textSize': settings.fontSize.round(),
      'lineSpacingExtra': 8,
      'paragraphSpacing': 4,
      'paddingTop': 16,
      'paddingBottom': 16,
      'paddingLeft': 16,
      'paddingRight': 16,
      'headerPaddingTop': 8,
      'footerPaddingBottom': 8,
      'letterSpacing': 0.0,
      'textBold': 0,
      'font': '',
      'darkStatusIcon': Color(foreground).computeLuminance() < 0.5,
      'tipHeaderLeft': 'title',
      'tipHeaderMiddle': '',
      'tipHeaderRight': 'battery',
      'tipFooterLeft': 'chapterTitle',
      'tipFooterMiddle': '',
      'tipFooterRight': 'page',
      'tipColor': '#99999900',
      '_bgColorHex':
          '#${background.toRadixString(16).padLeft(8, '0').toUpperCase()}',
    });
  }
}
