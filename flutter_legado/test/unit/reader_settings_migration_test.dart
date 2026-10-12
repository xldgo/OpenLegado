import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/screens/reader_config_panel.dart';
import 'package:flutter_legado/src/services/reader_settings_migration.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('保留最后使用的夜间排版并清理分桶，后续不切换也不覆盖用户新值', () async {
    SharedPreferences.setMockInitialValues({
      'reader_layout_is_night': true,
      'shareLayout': false,
      'reader_layout_night_margin_left': 29.0,
      'reader_layout_day_margin_left': 17.0,
      'reader_layout_night_header_padding_top': 14.0,
      'reader_layout_night_letter_spacing': 0.25,
      'reader_layout_night_textBold': 1,
      'reader_layout_night_show_footer_line': false,
    });
    final loaded = await ReaderAdvancedConfig.load();
    expect(loaded.pageMarginLeft, 29);
    expect(loaded.headerPaddingTop, 14);
    expect(loaded.letterSpacing, 0.25);
    expect(loaded.textBold, 1);
    expect(loaded.showFooterLine, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getKeys().any((key) => key.startsWith('reader_layout_')),
      isFalse,
    );
    expect(prefs.containsKey('shareLayout'), isFalse);
    loaded.pageMarginLeft = 23;
    await loaded.save();
    final restored = await ReaderAdvancedConfig.load();
    expect(restored.pageMarginLeft, 23);
    expect(
      prefs.getKeys().any((key) => key.startsWith('reader_layout_')),
      isFalse,
    );
  });

  test('原共用排版优先，缺失字段保留现有全局值', () async {
    SharedPreferences.setMockInitialValues({
      'shareLayout': true,
      'reader_layout_is_night': true,
      'reader_layout_share_margin_top': 40.0,
      'reader_layout_night_margin_top': 10.0,
      'reader_adv_margin_bottom': 31.0,
    });
    final config = await ReaderAdvancedConfig.load();
    expect(config.pageMarginTop, 40);
    expect(config.pageMarginBottom, 31);
  });

  test('迁移中断后只清理剩余旧键，不用另一套排版覆盖已保存的新值', () async {
    SharedPreferences.setMockInitialValues({
      'reader_unified_layout_v1': true,
      'reader_adv_margin_left': 29.0,
      'reader_layout_day_margin_left': 17.0,
    });
    final prefs = await SharedPreferences.getInstance();
    await migrateReaderSettings(prefs);
    expect(prefs.getDouble('reader_adv_margin_left'), 29);
    expect(prefs.containsKey('reader_unified_layout_v1'), isFalse);
    expect(prefs.containsKey('reader_layout_day_margin_left'), isFalse);
  });
}
