import 'package:shared_preferences/shared_preferences.dart';

/// 只在旧键仍存在时执行；运行时读取和保存统一使用单套排版键。
Future<void> migrateReaderSettings(SharedPreferences prefs) async {
  final keys = prefs.getKeys();
  bool legacyLayoutKey(String key) =>
      key == 'reader_layout_is_night' ||
      key.startsWith('reader_layout_share_') ||
      key.startsWith('reader_layout_day_') ||
      key.startsWith('reader_layout_night_');
  final hasLayouts = keys.any(legacyLayoutKey);
  if (hasLayouts || keys.contains('shareLayout')) {
    const migratedKey = 'reader_unified_layout_v1';
    final selected = prefs.getBool('shareLayout') == true
        ? 'reader_layout_share_'
        : prefs.getBool('reader_layout_is_night') == true
        ? 'reader_layout_night_'
        : 'reader_layout_day_';
    const layoutKeys = {
      'paragraph_spacing': 'reader_adv_paragraph_spacing',
      'letter_spacing': 'reader_adv_letter_spacing',
      'paragraph_indent_chars': 'reader_adv_paragraph_indent_chars',
      'margin_top': 'reader_adv_margin_top',
      'margin_bottom': 'reader_adv_margin_bottom',
      'margin_left': 'reader_adv_margin_left',
      'margin_right': 'reader_adv_margin_right',
      'header_padding_top': 'reader_adv_header_padding_top',
      'header_padding_bottom': 'reader_adv_header_padding_bottom',
      'header_padding_left': 'reader_adv_header_padding_left',
      'header_padding_right': 'reader_adv_header_padding_right',
      'footer_padding_top': 'reader_adv_footer_padding_top',
      'footer_padding_bottom': 'reader_adv_footer_padding_bottom',
      'footer_padding_left': 'reader_adv_footer_padding_left',
      'footer_padding_right': 'reader_adv_footer_padding_right',
      'show_header_line': 'showHeaderLine',
      'show_footer_line': 'showFooterLine',
      'textBold': 'textBold',
    };
    if (!(prefs.getBool(migratedKey) ?? false)) {
      for (final entry in layoutKeys.entries) {
        final value = prefs.get('$selected${entry.key}');
        if (value is bool) await prefs.setBool(entry.value, value);
        if (value is num) {
          if (const {
            'paragraph_indent_chars',
            'textBold',
          }.contains(entry.key)) {
            await prefs.setInt(entry.value, value.toInt());
          } else {
            await prefs.setDouble(entry.value, value.toDouble());
          }
        }
        if (entry.key == 'letter_spacing' && value is num) {
          await prefs.setBool('reader_adv_letter_spacing_migrated', true);
        }
      }
      await prefs.setBool(migratedKey, true);
    }
    // 中断后可以重复执行：先保存完整新值，再移除分桶和旧开关。
    for (final key in keys.where(legacyLayoutKey)) {
      await prefs.remove(key);
    }
    await prefs.remove('shareLayout');
    await prefs.remove(migratedKey);
  }
  if (prefs.containsKey('readBarStyleFollowPage')) {
    if (!prefs.containsKey('readBarStyle')) {
      await prefs.setInt(
        'readBarStyle',
        prefs.getBool('readBarStyleFollowPage') == true ? 1 : 0,
      );
    }
    await prefs.remove('readBarStyleFollowPage');
  }
}
