import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/contracts/theme_preset_repository.dart';
import '../../models/theme_preset.dart';
import '../../services/settings_write_queue.dart';

/// 复用既有偏好键，串行完成列表的读改写，避免连续保存丢失条目。
class PreferencesThemePresetRepository implements ThemePresetRepository {
  PreferencesThemePresetRepository({
    Future<SharedPreferences> Function()? loadPreferences,
  }) : _loadPreferences = loadPreferences ?? SharedPreferences.getInstance;

  static const storageKey = 'themeConfigList';
  final Future<SharedPreferences> Function() _loadPreferences;
  final SettingsWriteQueue _writes = SettingsWriteQueue();

  List<ThemePreset> _read(SharedPreferences prefs) {
    final raw = prefs.getString(storageKey) ?? '';
    if (raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .map(ThemePreset.fromJson)
          .toList();
    } catch (_) {
      // 损坏JSON沿用空列表回退；平台读取异常不在这里吞掉。
      return [];
    }
  }

  @override
  Future<List<ThemePreset>> readAll() async {
    late List<ThemePreset> result;
    await _writes.run(() async => result = _read(await _loadPreferences()));
    return result;
  }

  Future<void> _save(SharedPreferences prefs, List<ThemePreset> presets) async {
    final previous = prefs.getString(storageKey);
    try {
      if (!await prefs.setString(
        storageKey,
        jsonEncode(presets.map((preset) => preset.toJson()).toList()),
      )) {
        throw StateError('主题预设写入被拒绝');
      }
    } catch (_) {
      var restored = false;
      try {
        restored = previous == null
            ? await prefs.remove(storageKey)
            : await prefs.setString(storageKey, previous);
      } catch (_) {
        // 原列表恢复失败也必须报告，不能将本次修改视为成功。
      }
      throw StateError(restored ? '主题预设保存失败，请重试' : '主题预设保存失败，原列表恢复失败，请重试');
    }
  }

  @override
  Future<void> add(ThemePreset preset) => _writes.run(() async {
    final prefs = await _loadPreferences();
    final list = _read(prefs);
    list.add(preset);
    await _save(prefs, list);
  });

  @override
  Future<List<ThemePreset>> removeAt(int index) async {
    late List<ThemePreset> result;
    await _writes.run(() async {
      final prefs = await _loadPreferences();
      result = _read(prefs);
      result.removeAt(index);
      await _save(prefs, result);
    });
    return result;
  }
}
