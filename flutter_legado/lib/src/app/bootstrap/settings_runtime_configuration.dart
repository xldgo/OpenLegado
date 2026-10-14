import '../../data/repositories/app_appearance_settings_repository.dart';
import '../../domain/contracts/appearance_settings_repository.dart';
import '../../domain/models/appearance_settings.dart';
import '../../data/bridge/runtime_configuration.dart';
import '../../services/settings_service.dart';
import '../../theme/md3_colors.dart';
import 'app_settings_factory.dart';

/// 设置层把主题对象转成书源原有的数据协议。— Codex + UI
class SettingsRuntimeConfiguration implements RuntimeConfigurationSource {
  SettingsRuntimeConfiguration({
    SettingsService? settings,
    AppearanceSettingsRepository? appearance,
  }) : _settings = settings ?? SettingsService(),
       _appearance =
           appearance ??
           AppAppearanceSettingsRepository(createAppSettingsService());

  final SettingsService _settings;
  final AppearanceSettingsRepository _appearance;

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
    final fontSize = await _settings.getFontSize();
    final bgIndex = await _settings.getBgColorIndex();
    const bgStrs = ['#FFFFFF', '#CCEBCC', '#D4A574', '#E8E0C8', '#1A1A1A'];
    final bgStr = (bgIndex >= 0 && bgIndex < bgStrs.length)
        ? bgStrs[bgIndex]
        : '#FFFFFF';
    final isDark = bgIndex == 4;
    return RuntimeConfigSnapshot({
      'name': '默认',
      'bgStr': bgStr,
      'bgType': bgIndex,
      'textColor': isDark ? '#CCCCCC' : '#333333',
      'textSize': fontSize.round(),
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
      'darkStatusIcon': !isDark,
      'tipHeaderLeft': 'title',
      'tipHeaderMiddle': '',
      'tipHeaderRight': 'battery',
      'tipFooterLeft': 'chapterTitle',
      'tipFooterMiddle': '',
      'tipFooterRight': 'page',
      'tipColor': '#99999900',
      '_bgColorHex': isDark ? '#FF1A1A1A' : '#FFFFFFFF',
    });
  }
}
