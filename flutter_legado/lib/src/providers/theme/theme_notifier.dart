import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../../domain/contracts/appearance_settings_repository.dart';
import '../../domain/models/appearance_settings.dart';
import '../../features/appearance/appearance_settings_provider.dart';
import 'theme_state.dart';

export 'theme_state.dart';

/// 保存成功但原生同步失败，调用方只能重试同步，不能撤销已保存的设置。
final class AppearanceSyncException implements Exception {
  AppearanceSyncException(this.cause);
  final Object cause;

  @override
  String toString() => '设置已保存，主题同步失败：$cause';
}

/// 外观状态投影，持久化、并发和失败回退由共享设置服务拥有。— Codex + UI
class ThemeNotifier extends Notifier<ThemeState> {
  int _generation = 0;

  @override
  ThemeState build() {
    final repository = ref.watch(appearanceSettingsRepositoryProvider);
    final generation = ++_generation;
    final subscription = repository.watch().listen(
      (_) => _publish(repository, generation),
    );
    ref.onDispose(() => unawaited(subscription.cancel()));
    unawaited(
      Future.microtask(() async {
        try {
          if (_isCurrent(generation)) await load();
        } catch (error) {
          debugPrint('外观设置读取失败，保留当前快照，可重新加载：$error');
        }
      }),
    );
    return _stateFor(repository.current);
  }

  ThemeState _stateFor(AppearanceSettings settings) => ThemeState(
    themeMode: switch (settings.themeMode) {
      AppThemeMode.system => ThemeMode.system,
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
    },
    fontScaleRaw: settings.fontScaleRaw,
    paletteId: settings.paletteId,
  );

  bool _isCurrent(int generation) => ref.mounted && generation == _generation;

  void _publish(AppearanceSettingsRepository repository, int generation) {
    if (!_isCurrent(generation)) return;
    final next = _stateFor(repository.current);
    if (state != next) state = next;
  }

  Future<void> load() async {
    final repository = ref.read(appearanceSettingsRepositoryProvider);
    final generation = _generation;
    try {
      await repository.load();
    } finally {
      _publish(repository, generation);
    }
  }

  /// 恢复备份后重新读取原存储，并刷新现有原生主题快照。
  Future<void> reload() async {
    final repository = ref.read(appearanceSettingsRepositoryProvider);
    final generation = _generation;
    try {
      await repository.reload();
    } finally {
      _publish(repository, generation);
    }
    if (_isCurrent(generation)) await synchronizeRuntime();
  }

  Future<void> synchronizeRuntime() async {
    final repository = ref.read(appearanceSettingsRepositoryProvider);
    final sync = ref.read(themeConfigSyncProvider);
    final generation = _generation;
    await repository.settled();
    if (!_isCurrent(generation)) return;
    try {
      await sync.synchronizeThemeConfig();
    } catch (error) {
      if (_isCurrent(generation)) throw AppearanceSyncException(error);
    }
  }

  Future<void> _update(
    AppearanceSettings Function(AppearanceSettings) transform, {
    bool syncTheme = false,
  }) async {
    final repository = ref.read(appearanceSettingsRepositoryProvider);
    final generation = _generation;
    final saving = repository.update(transform);
    _publish(repository, generation);
    try {
      await saving;
    } finally {
      _publish(repository, generation);
    }
    if (syncTheme && _isCurrent(generation)) await synchronizeRuntime();
  }

  /// 导入时先保存全部普通外观偏好，再执行一次原生同步。
  Future<void> applyAppearance({ThemeMode? themeMode, String? paletteId}) =>
      _update(
        (current) => current.copyWith(
          themeMode: switch (themeMode) {
            ThemeMode.system => AppThemeMode.system,
            ThemeMode.light => AppThemeMode.light,
            ThemeMode.dark => AppThemeMode.dark,
            null => current.themeMode,
          },
          paletteId: paletteId,
        ),
        syncTheme: true,
      );

  Future<void> setThemeMode(ThemeMode mode) => applyAppearance(themeMode: mode);

  Future<void> toggleDayNight({required bool isNight}) =>
      setThemeMode(isNight ? ThemeMode.light : ThemeMode.dark);

  Future<void> setFontScale(int raw) =>
      _update((current) => current.copyWith(fontScaleRaw: raw));

  Future<void> setPaletteId(String id) => applyAppearance(paletteId: id);
}

final themeNotifierProvider = NotifierProvider<ThemeNotifier, ThemeState>(
  ThemeNotifier.new,
);
