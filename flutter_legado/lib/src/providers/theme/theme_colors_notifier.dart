// [UI-fix v2.0.5 | 2026-08-08] 自定义主题颜色状态管理：对齐原版
// pref_config_theme.xml 日间/夜间 主色调/强调色/背景色/底部操作栏颜色
// 8 个 ColorPreference（colorPrimary/colorAccent/colorBackground/
// colorBottomBackground 及 Night 变体），接入 MaterialApp ThemeData
// 即时生效 — Qoder
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../../constants/pref_keys.dart';
import '../../services/settings_service.dart';
import '../../services/settings_write_queue.dart';

/// 自定义主题颜色状态（字段为 ARGB int，null 表示未自定义、使用内置默认）
class ThemeColorsState {
  /// 日间主色调（对齐原版 colorPrimary，映射 AppBar 背景）
  final int? primary;

  /// 日间强调色（对齐原版 colorAccent，映射全局 Tint）
  final int? accent;

  /// 日间背景色（对齐原版 colorBackground，映射 Scaffold 背景）
  final int? background;

  /// 日间底部操作栏颜色（对齐原版 colorBottomBackground，映射底部 TabBar 背景）
  final int? bottomBackground;

  /// 夜间主色调（colorPrimaryNight）
  final int? primaryNight;

  /// 夜间强调色（colorAccentNight）
  final int? accentNight;

  /// 夜间背景色（colorBackgroundNight）
  final int? backgroundNight;

  /// 夜间底部操作栏颜色（colorBottomBackgroundNight）
  final int? bottomBackgroundNight;

  /// 日间背景图片本地路径（对齐原版 backgroundImage；空=未设置）
  final String bgImage;

  /// 夜间背景图片本地路径（对齐原版 backgroundImageNight）
  final String bgImageNight;

  const ThemeColorsState({
    this.primary,
    this.accent,
    this.background,
    this.bottomBackground,
    this.primaryNight,
    this.accentNight,
    this.backgroundNight,
    this.bottomBackgroundNight,
    this.bgImage = '',
    this.bgImageNight = '',
  });

  /// 按当前亮度返回应渲染的背景图路径（空串表示无图）
  String bgImageFor(Brightness brightness) =>
      brightness == Brightness.dark ? bgImageNight : bgImage;

  /// 按偏好键返回对应颜色值（供设置页展示当前值）
  int? valueOf(String key) {
    switch (key) {
      case PrefKeys.cPrimary:
        return primary;
      case PrefKeys.cAccent:
        return accent;
      case PrefKeys.cBackground:
        return background;
      case PrefKeys.cBBackground:
        return bottomBackground;
      case PrefKeys.cNPrimary:
        return primaryNight;
      case PrefKeys.cNAccent:
        return accentNight;
      case PrefKeys.cNBackground:
        return backgroundNight;
      case PrefKeys.cNBBackground:
        return bottomBackgroundNight;
      default:
        return null;
    }
  }

  /// 按偏好键生成替换单个颜色后的新状态（value 传 null 表示恢复默认）
  ThemeColorsState withValue(String key, int? value) {
    return ThemeColorsState(
      primary: key == PrefKeys.cPrimary ? value : primary,
      accent: key == PrefKeys.cAccent ? value : accent,
      background: key == PrefKeys.cBackground ? value : background,
      bottomBackground: key == PrefKeys.cBBackground ? value : bottomBackground,
      primaryNight: key == PrefKeys.cNPrimary ? value : primaryNight,
      accentNight: key == PrefKeys.cNAccent ? value : accentNight,
      backgroundNight: key == PrefKeys.cNBackground ? value : backgroundNight,
      bottomBackgroundNight: key == PrefKeys.cNBBackground
          ? value
          : bottomBackgroundNight,
      bgImage: bgImage,
      bgImageNight: bgImageNight,
    );
  }

  /// 替换背景图路径后的新状态
  ThemeColorsState withBgImage({String? day, String? night}) {
    return ThemeColorsState(
      primary: primary,
      accent: accent,
      background: background,
      bottomBackground: bottomBackground,
      primaryNight: primaryNight,
      accentNight: accentNight,
      backgroundNight: backgroundNight,
      bottomBackgroundNight: bottomBackgroundNight,
      bgImage: day ?? bgImage,
      bgImageNight: night ?? bgImageNight,
    );
  }
}

/// 自定义主题颜色 Notifier（读写 SharedPreferences 并驱动 MaterialApp 重建）
class ThemeColorsNotifier extends Notifier<ThemeColorsState> {
  ThemeColorsNotifier({SettingsService? settings})
    : _settings = settings ?? SettingsService();

  final SettingsService _settings;

  final _writes = SettingsWriteQueue();
  final _edits = <String, int>{};
  final _changedValues = <String>{};
  int _revision = 0;
  int _loadGeneration = 0;

  void _markEdited(String key, {bool updateState = true}) {
    _edits[key] = ++_revision;
    if (updateState) _changedValues.add(key);
  }

  @override
  ThemeColorsState build() {
    _edits.clear();
    _changedValues.clear();
    final generation = ++_loadGeneration;
    Future.microtask(() => _load(generation));
    return const ThemeColorsState();
  }

  /// 启动恢复仅写入没有被用户修改的字段，离场或过期加载不再回写。
  Future<void> _load(int generation) async {
    if (!ref.mounted) return;
    var loaded = ThemeColorsState(
      primary: await _settings.getIntPrefOrNull(PrefKeys.cPrimary),
      accent: await _settings.getIntPrefOrNull(PrefKeys.cAccent),
      background: await _settings.getIntPrefOrNull(PrefKeys.cBackground),
      bottomBackground: await _settings.getIntPrefOrNull(PrefKeys.cBBackground),
      primaryNight: await _settings.getIntPrefOrNull(PrefKeys.cNPrimary),
      accentNight: await _settings.getIntPrefOrNull(PrefKeys.cNAccent),
      backgroundNight: await _settings.getIntPrefOrNull(PrefKeys.cNBackground),
      bottomBackgroundNight: await _settings.getIntPrefOrNull(
        PrefKeys.cNBBackground,
      ),
      bgImage: await _settings.getStringPref(PrefKeys.bgImage),
      bgImageNight: await _settings.getStringPref(PrefKeys.bgImageN),
    );
    if (!ref.mounted || generation != _loadGeneration) return;
    for (final key in _changedValues) {
      loaded = loaded.withValue(key, state.valueOf(key));
    }
    state = loaded.withBgImage(
      day: _changedValues.contains(PrefKeys.bgImage) ? state.bgImage : null,
      night: _changedValues.contains(PrefKeys.bgImageN)
          ? state.bgImageNight
          : null,
    );
  }

  /// 设置背景图；未传入的一侧不参与本次保存。
  Future<void> setBgImage({String? day, String? night}) {
    if (day != null) _markEdited(PrefKeys.bgImage);
    if (night != null) _markEdited(PrefKeys.bgImageN);
    final pending = _writes.run(() async {
      if (day != null) {
        if (day.isEmpty) {
          await _settings.removePref(PrefKeys.bgImage);
        } else {
          await _settings.setStringPref(PrefKeys.bgImage, day);
        }
      }
      if (night != null) {
        if (night.isEmpty) {
          await _settings.removePref(PrefKeys.bgImageN);
        } else {
          await _settings.setStringPref(PrefKeys.bgImageN, night);
        }
      }
    });
    state = state.withBgImage(day: day, night: night);
    return pending;
  }

  /// 单色即时更新；清除颜色与连续调色也按操作顺序保存。
  Future<void> setColor(String key, int? value) {
    _markEdited(key);
    final pending = _writes.run(
      () => value == null
          ? _settings.removePref(key)
          : _settings.setIntPref(key, value),
    );
    state = state.withValue(key, value);
    return pending;
  }

  /// 预设保存成功后只合并本批仍有效的字段，不回写较早的完整状态。
  Future<void> applyColors(Map<String, int?> colors) async {
    final snapshot = Map<String, int?>.unmodifiable(colors);
    final generation = _loadGeneration;
    for (final key in snapshot.keys) {
      _markEdited(key, updateState: false);
    }
    final revisions = {for (final key in snapshot.keys) key: _edits[key]};
    try {
      await _writes.run(() => _settings.setColorPrefs(snapshot));
    } catch (e) {
      debugPrint('ThemeColorsNotifier.applyColors 持久化异常: $e');
      return;
    }
    if (!ref.mounted || generation != _loadGeneration) return;
    var next = state;
    for (final entry in snapshot.entries) {
      if (_edits[entry.key] == revisions[entry.key]) {
        _changedValues.add(entry.key);
        next = next.withValue(entry.key, entry.value);
      }
    }
    state = next;
  }
}

/// 自定义主题颜色全局 Provider
final themeColorsProvider =
    NotifierProvider<ThemeColorsNotifier, ThemeColorsState>(
      ThemeColorsNotifier.new,
    );
