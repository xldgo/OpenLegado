import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 未迁移选项的只读适配；普通偏好由领域仓储管理。— Codex + UI
class SettingsService {
  // ===== 未接线选项读取 =====

  /// 读取尚未接线选项的原值；已迁移偏好由所属仓储管理。
  Future<bool> getBoolPref(String key, {required bool defaultValue}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(key) ?? defaultValue;
    } catch (e) {
      debugPrint('SettingsService.getBoolPref($key) 异常: $e');
      return defaultValue;
    }
  }

  /// 读取整数偏好，缺失时返回指定默认值。
  Future<int> getIntPref(String key, {required int defaultValue}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(key) ?? defaultValue;
    } catch (e) {
      debugPrint('SettingsService.getIntPref($key) 异常: $e');
      return defaultValue;
    }
  }

  /// 读取字符串偏好，缺失时返回指定默认值。
  Future<String> getStringPref(String key, {String defaultValue = ''}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key) ?? defaultValue;
    } catch (e) {
      debugPrint('SettingsService.getStringPref($key) 异常: $e');
      return defaultValue;
    }
  }
}
