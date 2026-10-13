// 沉浸式状态栏 / 导航栏偏好状态（对齐原版 transparentStatusBar / immNavigationBar）
//
// — Composer + UI ｜ 2026-08-14
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../../constants/pref_keys.dart';
import '../../services/settings_service.dart';
import '../../services/settings_write_queue.dart';
import '../providers.dart';

/// 系统栏偏好状态
class SystemBarState {
  final bool transparentStatusBar;
  final bool immNavigationBar;
  final bool loaded;

  const SystemBarState({
    this.transparentStatusBar = true,
    this.immNavigationBar = true,
    this.loaded = false,
  });

  SystemBarState copyWith({
    bool? transparentStatusBar,
    bool? immNavigationBar,
    bool? loaded,
  }) {
    return SystemBarState(
      transparentStatusBar: transparentStatusBar ?? this.transparentStatusBar,
      immNavigationBar: immNavigationBar ?? this.immNavigationBar,
      loaded: loaded ?? this.loaded,
    );
  }
}

class SystemBarNotifier extends Notifier<SystemBarState> {
  late SettingsService _settings;
  final _operations = SettingsWriteQueue();
  int _generation = 0;
  int _loadGeneration = 0;
  int _statusRevision = 0;
  int _navigationRevision = 0;

  @override
  SystemBarState build() {
    _settings = ref.watch(settingsProvider);
    _statusRevision = 0;
    _navigationRevision = 0;
    final generation = ++_generation;
    ref.onDispose(() => _generation++);
    unawaited(
      _loadFromPrefs().catchError((Object error) {
        if (ref.mounted && generation == _generation) {
          debugPrint('系统栏偏好加载失败: $error');
        }
      }),
    );
    return const SystemBarState();
  }

  Future<void> _loadFromPrefs() {
    final settings = _settings;
    final generation = _generation;
    final loadGeneration = ++_loadGeneration;
    final statusRevision = _statusRevision;
    final navigationRevision = _navigationRevision;
    bool isCurrent() =>
        ref.mounted &&
        generation == _generation &&
        loadGeneration == _loadGeneration;

    // 重新读取排在此前的保存之后，避免恢复尚未落盘的旧值。
    return _operations.run(() async {
      if (!isCurrent()) return;
      final transparentStatusBar = await settings.getBoolPref(
        PrefKeys.transparentStatusBar,
        defaultValue: true,
      );
      if (!isCurrent()) return;
      final immNavigationBar = await settings.getBoolPref(
        PrefKeys.immNavigationBar,
        defaultValue: true,
      );
      if (!isCurrent()) return;
      // 即使用户显式选择默认值，也保留加载期间的这次操作。
      state = state.copyWith(
        transparentStatusBar: _statusRevision == statusRevision
            ? transparentStatusBar
            : null,
        immNavigationBar: _navigationRevision == navigationRevision
            ? immNavigationBar
            : null,
        loaded: true,
      );
    });
  }

  Future<void> setTransparentStatusBar(bool value) {
    _statusRevision++;
    state = state.copyWith(transparentStatusBar: value);
    final settings = _settings;
    return _operations.run(
      () => settings.setBoolPref(PrefKeys.transparentStatusBar, value),
    );
  }

  Future<void> setImmNavigationBar(bool value) {
    _navigationRevision++;
    state = state.copyWith(immNavigationBar: value);
    final settings = _settings;
    return _operations.run(
      () => settings.setBoolPref(PrefKeys.immNavigationBar, value),
    );
  }

  Future<void> reload() => _loadFromPrefs();
}

final systemBarProvider = NotifierProvider<SystemBarNotifier, SystemBarState>(
  SystemBarNotifier.new,
);
