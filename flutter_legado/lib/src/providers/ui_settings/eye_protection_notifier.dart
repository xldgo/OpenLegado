import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/contracts/eye_protection_settings_repository.dart';
import '../../domain/models/eye_protection_settings.dart';
import '../eye_protection_settings_provider.dart';

/// 护眼偏好仅投影共享快照，时段与滤镜规则保持。— Codex + UI
class EyeProtectionNotifier extends Notifier<EyeProtectionSettings> {
  int _generation = 0;
  @override
  EyeProtectionSettings build() {
    final repository = ref.watch(eyeProtectionSettingsRepositoryProvider);
    final generation = ++_generation;
    final subscription = repository.watch().listen(
      (_) => _publish(repository, generation),
    );
    ref.onDispose(() => unawaited(subscription.cancel()));
    unawaited(
      Future.microtask(() async {
        if (!ref.mounted || generation != _generation) return;
        try {
          await repository.load();
          _publish(repository, generation);
        } catch (error) {
          debugPrint('护眼设置读取失败，可重新加载：$error');
        }
      }),
    );
    return repository.current;
  }

  void _publish(EyeProtectionSettingsRepository repository, int generation) {
    if (!ref.mounted || generation != _generation) return;
    if (state != repository.current) state = repository.current;
  }

  Future<void> update({
    bool? enabled,
    int? intensity,
    bool? autoNight,
    bool? schedule,
    String? startTime,
    String? endTime,
  }) async {
    final repository = ref.read(eyeProtectionSettingsRepositoryProvider);
    final generation = _generation;
    try {
      final saving = repository.update(
        enabled: enabled,
        intensity: intensity,
        autoNight: autoNight,
        schedule: schedule,
        startTime: startTime,
        endTime: endTime,
      );
      _publish(repository, generation);
      await saving;
    } finally {
      _publish(repository, generation);
    }
  }

  Future<void> reload() async {
    final repository = ref.read(eyeProtectionSettingsRepositoryProvider);
    final generation = _generation;
    await repository.reload();
    _publish(repository, generation);
  }
}

final eyeProtectionProvider =
    NotifierProvider<EyeProtectionNotifier, EyeProtectionSettings>(
      EyeProtectionNotifier.new,
    );
