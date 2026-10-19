// 沉浸式状态栏 / 导航栏偏好状态（对齐原版 transparentStatusBar / immNavigationBar）
//
// — Composer + UI ｜ 2026-08-14
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../../domain/contracts/system_bar_settings_repository.dart';
import '../../domain/models/system_bar_settings.dart';
import 'system_bar_settings_provider.dart';

/// 系统栏偏好投影；加载信息不进入持久化模型。— Codex + UI
final class SystemBarState {
  const SystemBarState({
    this.settings = const SystemBarSettings(),
    this.loaded = false,
    this.loadError,
  });

  final SystemBarSettings settings;
  final bool loaded;
  final Object? loadError;

  bool get transparentStatusBar => settings.transparentStatusBar;
  bool get immNavigationBar => settings.immNavigationBar;

  @override
  bool operator ==(Object other) =>
      other is SystemBarState &&
      settings == other.settings &&
      loaded == other.loaded &&
      loadError == other.loadError;

  @override
  int get hashCode => Object.hash(settings, loaded, loadError);
}

/// 订阅共享设置并传递保存结果，不另建存储或写入队列。— Codex + UI
class SystemBarNotifier extends Notifier<SystemBarState> {
  int _generation = 0;
  bool _loaded = false;
  Object? _loadError;

  @override
  SystemBarState build() {
    final repository = ref.watch(systemBarSettingsRepositoryProvider);
    final generation = ++_generation;
    _loaded = false;
    _loadError = null;
    final subscription = repository.watch().listen(
      (_) => _publish(repository, generation),
    );
    ref.onDispose(() => unawaited(subscription.cancel()));
    unawaited(
      Future.microtask(() async {
        if (!_isCurrent(generation)) return;
        try {
          await load();
        } catch (error) {
          debugPrint('系统栏偏好读取失败，可重新加载：$error');
        }
      }),
    );
    return SystemBarState(settings: repository.current);
  }

  bool _isCurrent(int generation) => ref.mounted && generation == _generation;

  void _publish(SystemBarSettingsRepository repository, int generation) {
    if (!_isCurrent(generation)) return;
    final next = SystemBarState(
      settings: repository.current,
      loaded: _loaded,
      loadError: _loadError,
    );
    if (state != next) state = next;
  }

  Future<void> load() => _read(reload: false);
  Future<void> reload() => _read(reload: true);

  Future<void> _read({required bool reload}) async {
    final repository = ref.read(systemBarSettingsRepositoryProvider);
    final generation = _generation;
    try {
      if (reload) {
        await repository.reload();
      } else {
        await repository.load();
      }
      if (_isCurrent(generation)) {
        _loaded = true;
        _loadError = null;
      }
    } catch (error) {
      if (_isCurrent(generation)) _loadError = error;
      rethrow;
    } finally {
      _publish(repository, generation);
    }
  }

  Future<void> _update({
    bool? transparentStatusBar,
    bool? immNavigationBar,
  }) async {
    final repository = ref.read(systemBarSettingsRepositoryProvider);
    final generation = _generation;
    try {
      final saving = repository.update(
        transparentStatusBar: transparentStatusBar,
        immNavigationBar: immNavigationBar,
      );
      _publish(repository, generation);
      await saving;
    } finally {
      _publish(repository, generation);
    }
  }

  Future<void> setTransparentStatusBar(bool value) =>
      _update(transparentStatusBar: value);
  Future<void> setImmNavigationBar(bool value) =>
      _update(immNavigationBar: value);
}

final systemBarProvider = NotifierProvider<SystemBarNotifier, SystemBarState>(
  SystemBarNotifier.new,
);
