import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../domain/contracts/theme_preset_repository.dart';
import '../../models/theme_preset.dart';
import '../../services/settings_service.dart';
import '../../services/settings_write_queue.dart';

/// 复用既有偏好键，串行完成列表的读改写，避免连续保存丢失条目。
class PreferencesThemePresetRepository implements ThemePresetRepository {
  PreferencesThemePresetRepository(this._settings);

  static const storageKey = 'themeConfigList';
  final SettingsService _settings;
  final SettingsWriteQueue _writes = SettingsWriteQueue();

  Future<List<ThemePreset>> _read() async {
    final raw = await _settings.getStringPref(storageKey);
    if (raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .map(ThemePreset.fromJson)
          .toList();
    } catch (error) {
      debugPrint('主题预设解析异常: $error');
      return [];
    }
  }

  @override
  Future<List<ThemePreset>> readAll() async {
    late List<ThemePreset> result;
    await _writes.run(() async => result = await _read());
    return result;
  }

  Future<void> _save(List<ThemePreset> presets) =>
      _settings.setStringPrefChecked(
        storageKey,
        jsonEncode(presets.map((preset) => preset.toJson()).toList()),
      );

  @override
  Future<void> add(ThemePreset preset) => _writes.run(() async {
    final list = await _read();
    list.add(preset);
    await _save(list);
  });

  @override
  Future<List<ThemePreset>> removeAt(int index) async {
    late List<ThemePreset> result;
    await _writes.run(() async {
      result = await _read();
      result.removeAt(index);
      await _save(result);
    });
    return result;
  }
}
