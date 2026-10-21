import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/pref_keys.dart';
import '../../services/settings_write_queue.dart';

/// 备份 JSON 中偏好字段名（Flutter 单文件备份扩展，对齐原版 config.xml）
const kBackupAppPrefsKey = 'appPrefs';

/// 恢复忽略项的偏好备份/恢复（对齐 [BackupConfig.keyIsNotIgnore] + Restore 写 prefs）
///
/// 原版 ZIP 含 SharedPreferences `config`；重构版 JSON 仅有业务表时，
/// 由本助手在备份后注入 / 恢复前应用 `appPrefs`，使 ignore 键除 localBook 外亦可生效。
class BackupPreferencesService {
  BackupPreferencesService({
    Future<SharedPreferences> Function()? loadPreferences,
  }) : _loadPreferences = loadPreferences ?? SharedPreferences.getInstance;
  final Future<SharedPreferences> Function() _loadPreferences;
  final _queue = SettingsWriteQueue();

  /// 始终不备份/不恢复（对齐 BackupConfig.ignorePrefKeys）
  static const alwaysIgnoreKeys = <String>{
    PrefKeys.webServiceWakeLock,
    PrefKeys.defaultBookTreeUri,
    PrefKeys.bitmapCacheSize,
    'defaultCover',
    'defaultCoverDark',
    'backupPath',
    'webDavDeviceName',
    'jsSourceApiToken',
    PrefKeys.launcherIcon,
    'readAloudWakeLock',
    'audioPlayWakeLock',
    PrefKeys.restoreIgnore,
    'reader_unified_layout_v1',
  };

  /// 阅读界面相关键（对齐 BackupConfig.readPrefKeys + Flutter 阅读偏好）
  static const readPrefKeys = <String>{
    'readStyleSelect',
    'comicStyleSelect',
    'shareLayout',
    'hideStatusBar',
    'hideNavigationBar',
    'autoReadSpeed',
    'clickActionTL',
    'clickActionTC',
    'clickActionTR',
    'clickActionML',
    'clickActionMC',
    'clickActionMR',
    'clickActionBL',
    'clickActionBC',
    'clickActionBR',
    'reader_font_size',
    'reader_line_height',
    'reader_bg_color_index',
    'reader_styles',
    'reader_flip_mode',
    'reader_flip_mode_name',
    'reader_brightness',
    'reader_font_family',
    'reader_title_font_family',
    'reader_custom_fonts',
    'reader_toc_load_word_count',
    'reader_chapter_in_system_browser',
    'reader_menu_show_labels',
    'reader_paragraph_spacing_tenths',
    'reader_letter_spacing',
    'reader_paragraph_indent',
    'reader_text_full_justify',
    'reader_text_bottom_justify',
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
  };

  /// 主题颜色相关键（对齐 BackupConfig.themePrefKeys）
  static const themePrefKeys = <String>{
    'app_font_family',
    'eyeProtectionEnabled',
    'colorTemperature',
    'eyeProtectionAutoNight',
    'eyeProtectionSchedule',
    'eyeProtectionStartTime',
    'eyeProtectionEndTime',
    PrefKeys.cPrimary,
    PrefKeys.cAccent,
    PrefKeys.cBackground,
    PrefKeys.cBBackground,
    PrefKeys.bgImage,
    PrefKeys.bgImageN,
    PrefKeys.cNPrimary,
    PrefKeys.cNAccent,
    PrefKeys.cNBackground,
    PrefKeys.cNBBackground,
    'themeConfigList',
    'bgImageBlurring',
    'bgImageNBlurring',
  };

  /// 封面规则相关键（对齐 BackupConfig.coverPrefKeys）
  static const coverPrefKeys = <String>{
    PrefKeys.useDefaultCover,
    PrefKeys.loadCoverOnlyWifi,
    PrefKeys.coverShowName,
    PrefKeys.coverShowAuthor,
    'coverShowNameN',
    'coverShowAuthorN',
  };

  /// Flutter 侧主题模式存储键（SettingsService）
  static const themeModeStorageKey = 'app_theme_mode';

  /// Flutter 侧书架布局存储键
  static const bookshelfLayoutStorageKey = 'bookshelf_layout';

  /// 判断偏好键是否应写入备份 / 从备份恢复（对齐 BackupConfig.keyIsNotIgnore）
  static bool keyIsNotIgnore(String key, Map<String, bool> ignore) {
    if (alwaysIgnoreKeys.contains(key)) return false;
    if (ignore['readConfig'] == true && readPrefKeys.contains(key)) {
      return false;
    }
    if (ignore['themeConfig'] == true && themePrefKeys.contains(key)) {
      return false;
    }
    if (ignore['coverConfig'] == true && coverPrefKeys.contains(key)) {
      return false;
    }
    if (ignore['themeMode'] == true &&
        (key == 'themeMode' || key == themeModeStorageKey)) {
      return false;
    }
    if (ignore['bookshelfLayout'] == true &&
        (key == 'bookshelfLayout' || key == bookshelfLayoutStorageKey)) {
      return false;
    }
    if (ignore['showRss'] == true && key == PrefKeys.showRss) return false;
    if (ignore['threadCount'] == true && key == PrefKeys.threadCount) {
      return false;
    }
    return true;
  }

  /// 从当前 SharedPreferences 收集可备份偏好（已按 ignore 过滤）
  Future<Map<String, dynamic>> collectForBackup(
    Map<String, bool> ignore,
  ) async {
    final prefs = await _loadPreferences();
    final out = <String, dynamic>{};
    for (final key in prefs.getKeys()) {
      if (!keyIsNotIgnore(key, ignore)) continue;
      final value = prefs.get(key);
      if (value == null) continue;
      out[key] = value;
    }
    return out;
  }

  /// 将备份中的 appPrefs 写入 SharedPreferences（按 ignore 过滤）
  Future<void> applyFromBackup(
    Map<String, dynamic>? appPrefs,
    Map<String, bool> ignore,
  ) => _queue.run(() async {
    if (appPrefs == null || appPrefs.isEmpty) return;
    final prefs = await _loadPreferences();
    for (final entry in appPrefs.entries) {
      final key = entry.key;
      if (!keyIsNotIgnore(key, ignore)) continue;
      final value = entry.value;
      if (value == null) continue;
      final previous = prefs.get(key);
      try {
        if (!await _write(prefs, key, value)) throw StateError('写入被拒绝');
      } catch (error) {
        var restored = false;
        try {
          restored = previous == null
              ? await prefs.remove(key)
              : await _write(prefs, key, previous);
        } catch (_) {
          // 已写入的其他偏好保留，当前键回退失败也如实报告。
        }
        throw StateError('设置$key恢复失败${restored ? '' : '，原值恢复失败'}: $error');
      }
    }
  });

  Future<bool> _write(SharedPreferences prefs, String key, Object value) {
    if (value is bool) return prefs.setBool(key, value);
    if (value is int) return prefs.setInt(key, value);
    if (value is double) return prefs.setDouble(key, value);
    if (value is String) return prefs.setString(key, value);
    if (value is List) {
      return prefs.setStringList(key, value.map((e) => '$e').toList());
    }
    throw FormatException('不支持的设置类型：$key');
  }
}
