import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/app/bootstrap/settings_runtime_configuration.dart';
import 'package:flutter_legado/src/data/bridge/runtime_configuration.dart';
import 'package:flutter_legado/src/theme/md3_colors.dart';
import 'package:flutter_legado/src/app/bootstrap/app_settings_factory.dart';
import 'package:flutter_legado/src/data/repositories/app_reader_style_repository.dart';
import 'package:flutter_legado/src/data/repositories/app_reader_settings_repository.dart';
import 'package:flutter_legado/src/app/session/reader_theme_session.dart';
import 'package:flutter_legado/src/domain/models/reader_style.dart';
import 'package:flutter_legado/src/domain/models/reader_theme_mode.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('书源快照与模板日夜、自定义修改使用同一已装配服务，原字段类型保留', () async {
    SharedPreferences.setMockInitialValues({});
    final service = createAppSettingsService();
    addTearDown(service.dispose);
    final styles = AppReaderStyleRepository(service);
    final session = ReaderThemeSession();
    addTearDown(session.dispose);
    final source = SettingsRuntimeConfiguration(
      appSettings: service,
      readingSession: session,
    );
    await styles.load();
    await styles.select('preset3');
    var snapshot = await source.readReadBookConfig();
    expect(snapshot.fields['bgStr'], '#C2D8AA');
    expect(snapshot.fields['textColor'], '#596C44');
    expect(snapshot.fields['bgType'], 0);
    session.setMode(ReaderThemeMode.night);
    snapshot = await source.readReadBookConfig();
    expect(snapshot.fields['bgStr'], '#3C3F43');
    expect(snapshot.fields['textColor'], '#88C16F');
    await styles.updateColors(
      isNight: true,
      update: (colors) =>
          ReaderColors(background: colors.background, text: 0xFFAABBCC),
    );
    expect((await source.readReadBookConfig()).fields['textColor'], '#AABBCC');
    session.setMode(ReaderThemeMode.day);
    expect((await source.readReadBookConfig()).fields['textColor'], '#596C44');
  });

  test('快照复制平面数据，不持有输入 Map 的可变引用', () {
    final fields = <String, Object?>{'textSize': 20, 'letterSpacing': 0.0};
    final snapshot = RuntimeConfigSnapshot(fields);
    fields['textSize'] = 30;
    expect(jsonDecode(snapshot.encode()), {
      'textSize': 20,
      'letterSpacing': 0.0,
    });
    expect(() => snapshot.fields['textSize'] = 40, throwsUnsupportedError);
    expect(snapshot.fields['letterSpacing'], isA<double>());
  });

  for (final (stored, expected) in [
    ('system', '0'),
    ('light', '1'),
    ('dark', '2'),
    ('unknown', '0'),
  ]) {
    test('主题模式 $stored 保持旧注入值 $expected', () async {
      SharedPreferences.setMockInitialValues({'app_theme_mode': stored});
      expect(await SettingsRuntimeConfiguration().readThemeMode(), expected);
    });
  }

  for (final palette in Md3Palettes.all) {
    test('调色板 ${palette.id} 完整快照保持亮色角色及原颜色格式', () async {
      SharedPreferences.setMockInitialValues({
        'app_palette_id': palette.id,
        'app_theme_mode': 'dark',
      });
      final source = SettingsRuntimeConfiguration();
      String hex(int color) =>
          '#${color.toRadixString(16).padLeft(8, '0').toUpperCase()}';
      expect(jsonDecode((await source.readThemeConfig()).encode()), {
        'themeName': palette.label,
        'isNightTheme': false,
        'primaryColor': hex(palette.light.primary),
        'accentColor': hex(palette.light.secondary),
        'backgroundColor': hex(palette.light.surface),
        'bottomBackground': hex(palette.light.surfaceContainer),
        'statusBarColor': hex(palette.light.primary),
        'navigationBarColor': hex(palette.light.surface),
      });
      expect(await source.readThemeMode(), '2');
    });
  }

  const backgrounds = ['#FFFFFF', '#CCEBCC', '#D4A574', '#E8E0C8', '#1A1A1A'];
  for (final index in [-1, 0, 1, 2, 3, 4, 5]) {
    test('背景索引 $index 保持阅读快照全部字段及非法索引回退', () async {
      SharedPreferences.setMockInitialValues({
        'reader_font_size': 20.6,
        'reader_bg_color_index': index,
      });
      final snapshot = await SettingsRuntimeConfiguration()
          .readReadBookConfig();
      final dark = index == 4;
      expect(jsonDecode(snapshot.encode()), {
        'name': '自定义',
        'bgStr': index >= 0 && index < backgrounds.length
            ? backgrounds[index]
            : '#FFFFFF',
        'bgType': 0,
        'textColor': dark ? '#CCCCCC' : '#333333',
        'textSize': 21,
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
        'darkStatusIcon': !dark,
        'tipHeaderLeft': 'title',
        'tipHeaderMiddle': '',
        'tipHeaderRight': 'battery',
        'tipFooterLeft': 'chapterTitle',
        'tipFooterMiddle': '',
        'tipFooterRight': 'page',
        'tipColor': '#99999900',
        '_bgColorHex': index >= 0 && index < backgrounds.length
            ? '#FF${backgrounds[index].substring(1)}'
            : '#FFFFFFFF',
      });
      expect(snapshot.fields['textSize'], isA<int>());
      expect(snapshot.fields['letterSpacing'], isA<double>());
    });
  }

  test('字号共享更新及外部恢复重读产生新快照，旧快照保持不变', () async {
    SharedPreferences.setMockInitialValues({});
    final service = createAppSettingsService();
    addTearDown(service.dispose);
    final repository = AppReaderSettingsRepository(service);
    final source = SettingsRuntimeConfiguration(
      appSettings: service,
      readerSettings: repository,
    );
    final first = await source.readReadBookConfig();
    expect(first.fields['textSize'], 20);
    expect(first.fields['bgType'], 0);
    expect(await source.readThemeMode(), '0');
    await repository.update(fontSize: 24.6, lineHeight: 2.2);
    expect((await source.readReadBookConfig()).fields['textSize'], 25);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('reader_font_size', 27.0);
    expect((await source.readReadBookConfig()).fields['textSize'], 25);
    await repository.reload();
    final second = await source.readReadBookConfig();
    expect(second.fields['textSize'], 27);
    expect(first.fields['textSize'], 20);
  });
}
