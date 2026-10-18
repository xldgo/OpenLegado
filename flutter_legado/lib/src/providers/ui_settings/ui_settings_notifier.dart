import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../../domain/contracts/ui_settings_repository.dart';
import '../../domain/models/ui_settings.dart';
import 'ui_settings_repository_provider.dart';

export '../../domain/models/ui_settings.dart';

/// 只投影共享界面偏好，不直接访问存储或维护写队列。— Codex + UI
class UiSettingsNotifier extends Notifier<UiSettings> {
  int _generation = 0;

  @override
  UiSettings build() {
    final repository = ref.watch(uiSettingsRepositoryProvider);
    final generation = ++_generation;
    final subscription = repository.watch().listen(
      (_) => _publish(repository, generation),
    );
    ref.onDispose(() => unawaited(subscription.cancel()));
    unawaited(
      Future.microtask(() async {
        if (!ref.mounted || generation != _generation) return;
        try {
          await load();
        } catch (error) {
          debugPrint('界面偏好读取失败，可重新加载：$error');
        }
      }),
    );
    return repository.current;
  }

  void _publish(UiSettingsRepository repository, int generation) {
    if (!ref.mounted || generation != _generation) return;
    final next = repository.current;
    if (state != next) state = next;
  }

  Future<void> load() => _read(reload: false);
  Future<void> reload() => _read(reload: true);
  Future<void> _read({required bool reload}) async {
    final repository = ref.read(uiSettingsRepositoryProvider);
    final generation = _generation;
    if (reload) {
      await repository.reload();
    } else {
      await repository.load();
    }
    _publish(repository, generation);
  }

  Future<void> _save(Future<void> Function(UiSettingsRepository) save) async {
    final repository = ref.read(uiSettingsRepositoryProvider);
    final generation = _generation;
    try {
      final saving = save(repository);
      _publish(repository, generation);
      await saving;
    } finally {
      _publish(repository, generation);
    }
  }

  Future<void> setTopBarButtonStyle(TopBarButtonStyle value) =>
      _save((repository) => repository.update(topBarButtonStyle: value));

  Future<void> setMergeTopBarActions(bool value) =>
      _save((repository) => repository.update(mergeTopBarActions: value));

  Future<void> setUseFlexibleTopAppBar(bool value) =>
      _save((repository) => repository.update(useFlexibleTopAppBar: value));

  Future<void> setTopBarBackgroundOpacity(double value) =>
      _save((repository) => repository.update(topBarBackgroundOpacity: value));

  Future<void> setLabelVisibilityMode(BottomBarLabelMode value) =>
      _save((repository) => repository.update(labelVisibilityMode: value));

  Future<void> setBottomBarBackgroundOpacity(double value) => _save(
    (repository) => repository.update(bottomBarBackgroundOpacity: value),
  );

  Future<void> setUseFloatingBottomBar(bool value) =>
      _save((repository) => repository.update(useFloatingBottomBar: value));

  Future<void> setUseFloatingBottomBarLiquidGlass(bool value) => _save(
    (repository) => repository.update(useFloatingBottomBarLiquidGlass: value),
  );

  Future<void> setShowBottomView(bool value) =>
      _save((repository) => repository.update(showBottomView: value));

  Future<void> setTabletInterface(TabletInterfaceMode value) =>
      _save((repository) => repository.update(tabletInterface: value));

  Future<void> setBookInfoFollowCoverColor(bool value) =>
      _save((repository) => repository.update(bookInfoFollowCoverColor: value));

  Future<void> setOverrideBaseCardCornerRadius(bool value) => _save(
    (repository) => repository.update(overrideBaseCardCornerRadius: value),
  );

  Future<void> setBaseCardCornerRadius(int value) =>
      _save((repository) => repository.update(baseCardCornerRadius: value));

  Future<void> setEnableBlur(bool value) =>
      _save((repository) => repository.update(enableBlur: value));

  Future<void> setTopBarBlurSigma(double value) =>
      _save((repository) => repository.update(topBarBlurSigma: value));

  Future<void> setTopBarBlurTintOpacity(double value) =>
      _save((repository) => repository.update(topBarBlurTintOpacity: value));

  Future<void> setBottomBarBlurSigma(double value) =>
      _save((repository) => repository.update(bottomBarBlurSigma: value));

  Future<void> setBottomBarBlurTintOpacity(double value) =>
      _save((repository) => repository.update(bottomBarBlurTintOpacity: value));

  Future<void> setWallpaperColorFollow(bool value) =>
      _save((repository) => repository.update(wallpaperColorFollow: value));

  Future<void> setEnableItemDivider(bool value) =>
      _save((repository) => repository.update(enableItemDivider: value));

  Future<void> setRailExtended(bool value) =>
      _save((repository) => repository.update(railExtended: value));

  Future<void> setThemeStyle(String value) =>
      _save((repository) => repository.update(themeStyle: value));

  Future<void> setThemeContrastLevel(String value) =>
      _save((repository) => repository.update(themeContrastLevel: value));

  Future<void> setThemeAmoled(bool value) =>
      _save((repository) => repository.update(themeAmoled: value));

  Future<void> setBookInfoCoverBackground({
    required bool isDefaultCover,
    required String value,
  }) => _save(
    (repository) => isDefaultCover
        ? repository.update(bookInfoDefaultCoverBackground: value)
        : repository.update(bookInfoNetworkCoverBackground: value),
  );

  Future<void> setCardRadius({required bool override, required int radius}) =>
      _save(
        (repository) => repository.update(
          overrideBaseCardCornerRadius: override,
          baseCardCornerRadius: radius,
        ),
      );
  Future<void> setTopBarBlur({
    required double sigma,
    required double tintOpacity,
  }) => _save(
    (repository) => repository.update(
      topBarBlurSigma: sigma,
      topBarBlurTintOpacity: tintOpacity,
    ),
  );
  Future<void> setBottomBarBlur({
    required double sigma,
    required double tintOpacity,
  }) => _save(
    (repository) => repository.update(
      bottomBarBlurSigma: sigma,
      bottomBarBlurTintOpacity: tintOpacity,
    ),
  );
}

final uiSettingsProvider = NotifierProvider<UiSettingsNotifier, UiSettings>(
  UiSettingsNotifier.new,
);
