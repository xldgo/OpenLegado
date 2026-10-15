import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/constants/pref_keys.dart';
import 'package:flutter_legado/src/services/restore_ignore_prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RestoreIgnorePrefs.keyIsNotIgnore', () {
    test('默认全部可备份', () {
      expect(
        RestoreIgnorePrefs.keyIsNotIgnore(PrefKeys.showRss, const {}),
        isTrue,
      );
      expect(
        RestoreIgnorePrefs.keyIsNotIgnore('reader_font_size', const {}),
        isTrue,
      );
    });

    test('alwaysIgnore 永远跳过', () {
      expect(
        RestoreIgnorePrefs.keyIsNotIgnore(PrefKeys.launcherIcon, const {}),
        isFalse,
      );
      expect(
        RestoreIgnorePrefs.keyIsNotIgnore(PrefKeys.restoreIgnore, const {}),
        isFalse,
      );
    });

    test('勾选 readConfig 跳过阅读键', () {
      expect(
        RestoreIgnorePrefs.keyIsNotIgnore('reader_font_size', {
          'readConfig': true,
        }),
        isFalse,
      );
      expect(
        RestoreIgnorePrefs.keyIsNotIgnore(PrefKeys.showRss, {
          'readConfig': true,
        }),
        isTrue,
      );
    });

    test('阅读普通偏好及正文排版纳入配置备份忽略', () {
      for (final key in [
        'reader_toc_load_word_count',
        'reader_chapter_in_system_browser',
        'reader_paragraph_spacing',
        'reader_letter_spacing',
        'reader_paragraph_indent',
        'reader_text_full_justify',
        'reader_text_bold',
        'reader_italic',
        'reader_use_zh_layout',
        'reader_hanging_punctuation',
        'reader_page_margin_top',
        'reader_page_margin_bottom',
        'reader_page_margin_left',
        'reader_page_margin_right',
        'reader_double_horizontal_page',
        'reader_title_mode',
        'reader_title_size',
        'reader_title_top_spacing',
        'reader_title_bottom_spacing',
        'reader_header_padding_top',
        'reader_header_padding_bottom',
        'reader_header_padding_left',
        'reader_header_padding_right',
        'reader_header_mode',
        'reader_header_show_line',
        'reader_header_tip_left',
        'reader_header_tip_middle',
        'reader_header_tip_right',
        'reader_footer_padding_top',
        'reader_footer_padding_bottom',
        'reader_footer_padding_left',
        'reader_footer_padding_right',
        'reader_footer_mode',
        'reader_footer_show_line',
        'reader_footer_tip_left',
        'reader_footer_tip_middle',
        'reader_footer_tip_right',
        'reader_screen_orientation',
        'reader_hide_status_bar',
        'reader_hide_navigation_bar',
        'reader_extend_into_cutout',
        'reader_avoid_display_cutouts',
        'reader_status_show_battery',
        'reader_status_show_time',
        'reader_status_show_progress',
        'reader_status_show_chapter_name',
        'reader_auto_page_turn_enabled',
        'reader_auto_page_turn_interval_seconds',
        'reader_auto_page_turn_forward',
        'reader_tap_actions',
        'reader_select_text',
        'reader_no_anim_scroll_page',
        'reader_volume_key_page',
        'reader_volume_key_page_on_play',
        'reader_mouse_wheel_page',
        'reader_page_touch_slop',
        'reader_page_touch_click',
        'reader_progress_bar_behavior',
        'reader_auto_change_source',
        'reader_show_title_addition',
        'reader_keep_screen_on_seconds',
        'reader_menu_theme_mode',
        'reader_menu_palette_style',
        'reader_menu_color_mode',
        'reader_menu_accent_color',
        'reader_menu_accent_color_night',
        'reader_menu_background_color',
        'reader_menu_background_color_night',
        'reader_menu_container_color',
        'reader_menu_container_color_night',
        'reader_menu_text_color',
        'reader_menu_text_color_night',
        'reader_brightness_control_mode',
        'reader_brightness_control_on_left',
      ]) {
        expect(RestoreIgnorePrefs.keyIsNotIgnore(key, const {}), isTrue);
        expect(
          RestoreIgnorePrefs.keyIsNotIgnore(key, {'readConfig': true}),
          isFalse,
        );
      }
    });

    test('勾选 themeMode / showRss / threadCount / bookshelfLayout', () {
      expect(
        RestoreIgnorePrefs.keyIsNotIgnore(
          RestoreIgnorePrefs.themeModeStorageKey,
          {'themeMode': true},
        ),
        isFalse,
      );
      expect(
        RestoreIgnorePrefs.keyIsNotIgnore(PrefKeys.showRss, {'showRss': true}),
        isFalse,
      );
      expect(
        RestoreIgnorePrefs.keyIsNotIgnore(PrefKeys.threadCount, {
          'threadCount': true,
        }),
        isFalse,
      );
      expect(
        RestoreIgnorePrefs.keyIsNotIgnore(
          RestoreIgnorePrefs.bookshelfLayoutStorageKey,
          {'bookshelfLayout': true},
        ),
        isFalse,
      );
    });

    test('勾选 themeConfig / coverConfig', () {
      expect(
        RestoreIgnorePrefs.keyIsNotIgnore(PrefKeys.cPrimary, {
          'themeConfig': true,
        }),
        isFalse,
      );
      expect(
        RestoreIgnorePrefs.keyIsNotIgnore(PrefKeys.coverShowName, {
          'coverConfig': true,
        }),
        isFalse,
      );
    });
  });

  group('RestoreIgnorePrefs collect/apply', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        PrefKeys.showRss: false,
        PrefKeys.threadCount: 8,
        'reader_font_size': 20.0,
        PrefKeys.launcherIcon: 'icon_a',
        PrefKeys.restoreIgnore: '{"readConfig":true}',
      });
    });

    test('collect 按 ignore 过滤并跳过 alwaysIgnore', () async {
      final collected = await RestoreIgnorePrefs.collectForBackup({
        'readConfig': true,
      });
      expect(collected.containsKey(PrefKeys.showRss), isTrue);
      expect(collected[PrefKeys.showRss], isFalse);
      expect(collected[PrefKeys.threadCount], 8);
      expect(collected.containsKey('reader_font_size'), isFalse);
      expect(collected.containsKey(PrefKeys.launcherIcon), isFalse);
      expect(collected.containsKey(PrefKeys.restoreIgnore), isFalse);
    });

    test('apply 尊重 ignore 不覆盖本地项', () async {
      await RestoreIgnorePrefs.applyFromBackup(
        {
          PrefKeys.showRss: true,
          PrefKeys.threadCount: 32,
          'reader_font_size': 14.0,
          PrefKeys.restoreIgnore: '{"readConfig":false}',
        },
        {'showRss': true, 'readConfig': false},
      );
      final prefs = await SharedPreferences.getInstance();
      // showRss 忽略 → 保持 mock 初始 false
      expect(prefs.getBool(PrefKeys.showRss), isFalse);
      expect(prefs.getInt(PrefKeys.threadCount), 32);
      expect(prefs.getDouble('reader_font_size'), 14.0);
      expect(prefs.getString(PrefKeys.restoreIgnore), '{"readConfig":true}');
    });
  });
}
