import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 尚存连接、恢复配置与未迁移读取的底层适配；普通偏好由领域仓储管理。— Codex + UI
class SettingsService {
  // ===== WebDAV 云同步配置 =====

  static const _keyWebDavUrl = 'sync_webdav_url';
  static const _keyWebDavUsername = 'sync_webdav_username';
  static const _keyWebDavPassword = 'sync_webdav_password';
  static const _keyWebDavRemoteDir = 'sync_webdav_remote_dir';
  static const _keyWebDavDeviceName = 'sync_webdav_device_name';
  static const _keySyncBookProgressPlus = 'sync_book_progress_plus';
  static const _keyAutoSync = 'sync_auto';
  static const _keyLastSyncTime = 'sync_last_time';
  // 远程书库服务器（对齐原版 servers 表 + AppConfig.remoteServerId）
  static const _keyRemoteServers = 'remote_servers';
  static const _keyRemoteServerId = 'remote_server_id';

  /// 默认 WebDAV（同步设置），对齐原版 DEFAULT_WEBDAV_ID = -1
  static const int defaultRemoteServerId = -1;

  Future<String> getWebDavUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyWebDavUrl) ?? '';
    } catch (e) {
      debugPrint('SettingsService.getWebDavUrl 异常: $e');
      return '';
    }
  }

  Future<void> setWebDavUrl(String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyWebDavUrl, value);
    } catch (e) {
      debugPrint('SettingsService.setWebDavUrl 异常: $e');
    }
  }

  Future<String> getWebDavUsername() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyWebDavUsername) ?? '';
    } catch (e) {
      debugPrint('SettingsService.getWebDavUsername 异常: $e');
      return '';
    }
  }

  Future<void> setWebDavUsername(String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyWebDavUsername, value);
    } catch (e) {
      debugPrint('SettingsService.setWebDavUsername 异常: $e');
    }
  }

  Future<String> getWebDavPassword() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyWebDavPassword) ?? '';
    } catch (e) {
      debugPrint('SettingsService.getWebDavPassword 异常: $e');
      return '';
    }
  }

  Future<void> setWebDavPassword(String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyWebDavPassword, value);
    } catch (e) {
      debugPrint('SettingsService.setWebDavPassword 异常: $e');
    }
  }

  Future<String> getWebDavRemoteDir() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyWebDavRemoteDir) ?? '/legado/';
    } catch (e) {
      debugPrint('SettingsService.getWebDavRemoteDir 异常: $e');
      return '/legado/';
    }
  }

  Future<void> setWebDavRemoteDir(String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyWebDavRemoteDir, value);
    } catch (e) {
      debugPrint('SettingsService.setWebDavRemoteDir 异常: $e');
    }
  }

  Future<String> getWebDavDeviceName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyWebDavDeviceName) ?? '';
    } catch (e) {
      debugPrint('SettingsService.getWebDavDeviceName 异常: $e');
      return '';
    }
  }

  Future<void> setWebDavDeviceName(String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyWebDavDeviceName, value);
    } catch (e) {
      debugPrint('SettingsService.setWebDavDeviceName 异常: $e');
    }
  }

  /// 远程书库自定义服务器列表JSON，保留现有连接格式。
  Future<String> getRemoteServersJson() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyRemoteServers) ?? '[]';
    } catch (e) {
      debugPrint('SettingsService.getRemoteServersJson 异常: $e');
      return '[]';
    }
  }

  Future<void> setRemoteServersJson(String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyRemoteServers, value);
    } catch (e) {
      debugPrint('SettingsService.setRemoteServersJson 异常: $e');
    }
  }

  Future<int> getRemoteServerId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_keyRemoteServerId) ?? defaultRemoteServerId;
    } catch (e) {
      debugPrint('SettingsService.getRemoteServerId 异常: $e');
      return defaultRemoteServerId;
    }
  }

  Future<void> setRemoteServerId(int id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyRemoteServerId, id);
    } catch (e) {
      debugPrint('SettingsService.setRemoteServerId 异常: $e');
    }
  }

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

  // ===== 恢复忽略项（对齐 BackupConfig.restoreIgnore.json）=====

  /// 忽略键顺序与原版 [BackupConfig.ignoreKeys] 一致
  static const restoreIgnoreKeys = <String>[
    'readConfig',
    'themeMode',
    'themeConfig',
    'coverConfig',
    'bookshelfLayout',
    'showRss',
    'threadCount',
    'localBook',
  ];

  /// 忽略项标题（对齐 BackupConfig.ignoreTitle）
  static const restoreIgnoreTitles = <String>[
    '阅读界面配置',
    '主题模式',
    '主题配置',
    '封面规则',
    '书架布局',
    '显示订阅',
    '线程数',
    '本地书籍',
  ];

  static const _keyRestoreIgnore = 'restoreIgnore';

  /// 恢复忽略配置持久化键（供备份始终排除，避免恢复时覆盖本地忽略策略）
  static const restoreIgnoreStorageKey = _keyRestoreIgnore;

  /// 读取恢复忽略配置，缺省全部为false。
  Future<Map<String, bool>> getRestoreIgnoreConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyRestoreIgnore);
      if (raw == null || raw.isEmpty) {
        return {for (final k in restoreIgnoreKeys) k: false};
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return {for (final k in restoreIgnoreKeys) k: false};
      }
      return {for (final k in restoreIgnoreKeys) k: decoded[k] == true};
    } catch (e) {
      debugPrint('SettingsService.getRestoreIgnoreConfig 异常: $e');
      return {for (final k in restoreIgnoreKeys) k: false};
    }
  }

  /// 按既有忽略键集合保存恢复配置。
  Future<void> saveRestoreIgnoreConfig(Map<String, bool> config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final normalized = {
        for (final k in restoreIgnoreKeys) k: config[k] == true,
      };
      await prefs.setString(_keyRestoreIgnore, jsonEncode(normalized));
    } catch (e) {
      debugPrint('SettingsService.saveRestoreIgnoreConfig 异常: $e');
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
