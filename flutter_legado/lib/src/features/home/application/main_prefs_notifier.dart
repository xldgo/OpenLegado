import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../../../domain/contracts/home_settings_repository.dart';
import '../../../domain/models/home_settings.dart';
import '../../../providers/home_settings_provider.dart';

/// 偏好快照的界面投影，加载信息不进入持久化模型。— Codex + UI
final class MainPrefsState {
  const MainPrefsState({
    this.settings = const HomeSettings(),
    this.loaded = false,
    this.loadError,
  });

  final HomeSettings settings;
  final bool loaded;
  final Object? loadError;

  bool get showDiscovery => settings.showDiscovery;
  bool get showRss => settings.showRss;
  String get defaultHomePage => settings.defaultHomePage;

  @override
  bool operator ==(Object other) =>
      other is MainPrefsState &&
      settings == other.settings &&
      loaded == other.loaded &&
      loadError == other.loadError;

  @override
  int get hashCode => Object.hash(settings, loaded, loadError);
}

/// 订阅共享偏好并传递操作结果，不另建存储或写队列。— Codex + UI
class MainPrefsNotifier extends Notifier<MainPrefsState> {
  int _generation = 0;
  bool _loaded = false;
  Object? _loadError;

  @override
  MainPrefsState build() {
    final repository = ref.watch(homeSettingsRepositoryProvider);
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
          debugPrint('主界面偏好读取失败，保留当前快照，可重新加载：$error');
        }
      }),
    );
    return MainPrefsState(settings: repository.current);
  }

  bool _isCurrent(int generation) => ref.mounted && generation == _generation;

  void _publish(HomeSettingsRepository repository, int generation) {
    if (!_isCurrent(generation)) return;
    final next = MainPrefsState(
      settings: repository.current,
      loaded: _loaded,
      loadError: _loadError,
    );
    if (state != next) state = next;
  }

  Future<void> load() => _read(reload: false);
  Future<void> reload() => _read(reload: true);

  Future<void> _read({required bool reload}) async {
    final repository = ref.read(homeSettingsRepositoryProvider);
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
    bool? showDiscovery,
    bool? showRss,
    String? defaultHomePage,
  }) async {
    final repository = ref.read(homeSettingsRepositoryProvider);
    final generation = _generation;
    try {
      final saving = repository.update(
        showDiscovery: showDiscovery,
        showRss: showRss,
        defaultHomePage: defaultHomePage,
      );
      _publish(repository, generation);
      await saving;
    } finally {
      _publish(repository, generation);
    }
  }

  Future<void> setShowDiscovery(bool value) => _update(showDiscovery: value);
  Future<void> setShowRss(bool value) => _update(showRss: value);
  Future<void> setDefaultHomePage(String value) =>
      _update(defaultHomePage: value);
}

final mainPrefsProvider = NotifierProvider<MainPrefsNotifier, MainPrefsState>(
  MainPrefsNotifier.new,
);
