import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/contracts/theme_colors_settings_repository.dart';
import '../../domain/models/theme_colors_settings.dart';
import 'theme_colors_settings_provider.dart';

/// 只投影共享颜色快照，持久化失败由原调用方处理。— Codex + UI
class ThemeColorsNotifier extends Notifier<ThemeColorsSettings> {
  @override
  ThemeColorsSettings build() {
    final repository = ref.watch(themeColorsSettingsRepositoryProvider);
    final subscription = repository.watch().listen((_) => _publish(repository));
    ref.onDispose(() => unawaited(subscription.cancel()));
    unawaited(
      Future.microtask(() async {
        if (!ref.mounted) return;
        try {
          await load();
        } catch (error) {
          debugPrint('主题颜色读取失败，可重新加载：$error');
        }
      }),
    );
    return repository.current;
  }

  void _publish(ThemeColorsSettingsRepository repository) {
    if (ref.mounted && state != repository.current) state = repository.current;
  }

  Future<void> load() async {
    final repository = ref.read(themeColorsSettingsRepositoryProvider);
    try {
      await repository.load();
    } finally {
      _publish(repository);
    }
  }

  Future<void> reload() async {
    final repository = ref.read(themeColorsSettingsRepositoryProvider);
    try {
      await repository.reload();
    } finally {
      _publish(repository);
    }
  }

  Future<void> _save(
    Future<void> Function(ThemeColorsSettingsRepository) save,
  ) async {
    final repository = ref.read(themeColorsSettingsRepositoryProvider);
    try {
      final saving = save(repository);
      _publish(repository);
      await saving;
    } finally {
      _publish(repository);
    }
  }

  Future<void> setColor(ThemeColorRole role, int? value) =>
      applyColors({role: value});

  /// 多键沿用逐项落盘语义；失败向上传播，不宣称整批应用成功。
  Future<void> applyColors(Map<ThemeColorRole, int?> colors) =>
      _save((repository) => repository.setColors(colors));

  Future<void> setBgImage({String? day, String? night}) =>
      _save((repository) => repository.setBgImage(day: day, night: night));
}

final themeColorsProvider =
    NotifierProvider<ThemeColorsNotifier, ThemeColorsSettings>(
      ThemeColorsNotifier.new,
    );
