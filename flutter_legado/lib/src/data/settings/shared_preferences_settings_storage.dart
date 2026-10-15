import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/contracts/settings_storage.dart';
import '../../domain/models/app_settings_snapshot.dart';

/// 只操作请求的普通偏好键；不扫描凭据或其他功能数据。— Codex + UI
final class SharedPreferencesSettingsStorage implements SettingsStorage {
  SharedPreferencesSettingsStorage({
    Future<SharedPreferences> Function()? preferences,
  }) : _preferences = preferences ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _preferences;

  @override
  Future<Object?> read(String key) async => (await _preferences()).get(key);

  @override
  Future<void> write(String key, Object? value) async {
    final preferences = await _preferences();
    final saved = await switch (value) {
      null => preferences.remove(key),
      bool value => preferences.setBool(key, value),
      String value => preferences.setString(key, value),
      int value => preferences.setInt(key, value),
      double value => preferences.setDouble(key, value),
      SettingsStringList value => preferences.setStringList(key, value.values),
      _ => throw ArgumentError('普通偏好不支持此类型：$key'),
    };
    if (!saved) throw StateError('设置保存失败：$key');
  }
}
