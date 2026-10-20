import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/pref_keys.dart';
import '../../domain/contracts/restore_ignore_repository.dart';
import '../../domain/models/restore_ignore_config.dart';
import '../../services/settings_write_queue.dart';

/// 保留单个JSON偏好键，串行读写并恢复失败写入的当前键。— connection_migration + UI
final class PreferencesRestoreIgnoreRepository
    implements RestoreIgnoreRepository {
  PreferencesRestoreIgnoreRepository({
    Future<SharedPreferences> Function()? loadPreferences,
  }) : _loadPreferences = loadPreferences ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _loadPreferences;
  final _queue = SettingsWriteQueue();

  @override
  Future<RestoreIgnoreConfig> load() async {
    late RestoreIgnoreConfig config;
    await _queue.run(() async {
      final String? raw;
      try {
        raw = (await _loadPreferences()).getString(PrefKeys.restoreIgnore);
      } catch (_) {
        throw StateError('恢复忽略项读取失败，请重试');
      }
      try {
        final decoded = raw == null || raw.isEmpty ? null : jsonDecode(raw);
        config = RestoreIgnoreConfig({
          if (decoded is Map)
            for (final key in RestoreIgnoreConfig.keys) key: decoded[key],
        });
      } catch (_) {
        // 缺省或损坏JSON保持原全部不忽略的行为，不补写原存储。
        config = RestoreIgnoreConfig();
      }
    });
    return config;
  }

  @override
  Future<void> save(RestoreIgnoreConfig config) => _queue.run(() async {
    final prefs = await _loadPreferences();
    final previous = prefs.getString(PrefKeys.restoreIgnore);
    try {
      if (!await prefs.setString(
        PrefKeys.restoreIgnore,
        jsonEncode(config.values),
      )) {
        throw StateError('恢复忽略项写入被拒绝');
      }
    } catch (_) {
      var restored = false;
      try {
        restored = previous == null
            ? await prefs.remove(PrefKeys.restoreIgnore)
            : await prefs.setString(PrefKeys.restoreIgnore, previous);
      } catch (_) {
        // 回退失败仍由调用方提示，不能报告已保存。
      }
      throw StateError(restored ? '恢复忽略项保存失败，请重试' : '恢复忽略项保存失败，原配置恢复失败，请重试');
    }
  });
}
