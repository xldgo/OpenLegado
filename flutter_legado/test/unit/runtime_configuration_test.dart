import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/app/bootstrap/settings_runtime_configuration.dart';
import 'package:flutter_legado/src/data/bridge/runtime_configuration.dart';
import 'package:flutter_legado/src/theme/md3_colors.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
        'name': '默认',
        'bgStr': index >= 0 && index < backgrounds.length
            ? backgrounds[index]
            : '#FFFFFF',
        'bgType': index,
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
        '_bgColorHex': dark ? '#FF1A1A1A' : '#FFFFFFFF',
      });
      expect(snapshot.fields['textSize'], isA<int>());
      expect(snapshot.fields['letterSpacing'], isA<double>());
    });
  }

  test('缺少设置时保留默认值；再次读取获得新快照，旧快照不变', () async {
    SharedPreferences.setMockInitialValues({});
    final source = SettingsRuntimeConfiguration();
    final first = await source.readReadBookConfig();
    expect(first.fields['textSize'], 20);
    expect(first.fields['bgType'], 0);
    expect(await source.readThemeMode(), '0');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('reader_font_size', 27.0);
    final second = await source.readReadBookConfig();
    expect(second.fields['textSize'], 27);
    expect(first.fields['textSize'], 20);
  });
}
