import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 尚存同步元数据与未迁移读取的底层适配；普通偏好由领域仓储管理。— Codex + UI
class SettingsService {
  // ===== WebDAV 云同步配置 =====

  static const _keySyncBookProgressPlus = 'sync_book_progress_plus';
  static const _keyAutoSync = 'sync_auto';
  static const _keyLastSyncTime = 'sync_last_time';
  Future<bool> getSyncBookProgressPlus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keySyncBookProgressPlus) ?? false;
    } catch (e) {
      debugPrint('SettingsService.getSyncBookProgressPlus 异常: $e');
      return false;
    }
  }

  Future<void> setSyncBookProgressPlus(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keySyncBookProgressPlus, value);
    } catch (e) {
      debugPrint('SettingsService.setSyncBookProgressPlus 异常: $e');
    }
  }

  Future<bool> getAutoSync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyAutoSync) ?? false;
    } catch (e) {
      debugPrint('SettingsService.getAutoSync 异常: $e');
      return false;
    }
  }

  Future<void> setAutoSync(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyAutoSync, value);
    } catch (e) {
      debugPrint('SettingsService.setAutoSync 异常: $e');
    }
  }

  Future<DateTime?> getLastSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final millis = prefs.getInt(_keyLastSyncTime);
      return millis != null
          ? DateTime.fromMillisecondsSinceEpoch(millis)
          : null;
    } catch (e) {
      debugPrint('SettingsService.getLastSyncTime 异常: $e');
      return null;
    }
  }

  Future<void> setLastSyncTime(DateTime time) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyLastSyncTime, time.millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('SettingsService.setLastSyncTime 异常: $e');
    }
  }

  // ===== 未接线选项读取与主题预设存储 =====

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

  /// 结构化主题预设使用检查写入结果的入口，失败交给调用方。
  Future<void> setStringPrefChecked(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(key, value)) {
      throw StateError('偏好保存失败：$key');
    }
  }
}
