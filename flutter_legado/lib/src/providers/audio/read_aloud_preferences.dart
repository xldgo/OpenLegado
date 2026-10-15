import '../../domain/models/read_aloud_content.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../../domain/contracts/read_aloud_settings_repository.dart';
import '../../domain/models/read_aloud_settings.dart';
import '../../features/read_aloud/read_aloud_settings_provider.dart';

/// 只为现有控制层附加加载状态；设置值及默认值来自同一个领域快照。— Codex + UI
final class ReadAloudPreferences {
  const ReadAloudPreferences({
    this.settings = const ReadAloudSettings(),
    this.loaded = false,
  });

  final ReadAloudSettings settings;
  final bool loaded;

  ReadAloudSplitMode get splitMode => settings.splitMode;
  String get splitSymbols => settings.splitSymbols;
  bool get followSystem => settings.followSystem;
  bool get detachReminder => settings.detachReminder;
  bool get mediaButtonPerNext => settings.mediaButtonPerNext;
  double get manualSpeed => settings.manualSpeed;
  int get paragraphIntervalMs => settings.paragraphIntervalMs;
  int get audioPreDownloadNum => settings.audioPreDownloadNum;
  int get ttsPreSynthesisConcurrency => settings.ttsPreSynthesisConcurrency;
  int get audioCacheCleanTime => settings.audioCacheCleanTime;
  bool get hasStoredManualSpeed => settings.hasStoredManualSpeed;
  double get effectiveSpeed => settings.effectiveSpeed;
}

class ReadAloudPreferencesNotifier extends Notifier<ReadAloudPreferences> {
  bool _loaded = false;
  int _generation = 0;

  @override
  ReadAloudPreferences build() {
    final repository = ref.watch(readAloudSettingsRepositoryProvider);
    final generation = ++_generation;
    _loaded = false;
    final subscription = repository.watch().listen((_) {
      _publish(repository, generation);
    });
    ref.onDispose(() => unawaited(subscription.cancel()));
    return ReadAloudPreferences(settings: repository.current);
  }

  bool _isCurrent(int generation) => ref.mounted && generation == _generation;

  void _publish(ReadAloudSettingsRepository repository, int generation) {
    if (!_isCurrent(generation)) return;
    // 异步通知只作为重读信号，不能用排队的旧快照盖掉较新的用户选择。
    final settings = repository.current;
    if (state.settings != settings || state.loaded != _loaded) {
      state = ReadAloudPreferences(settings: settings, loaded: _loaded);
    }
  }

  Future<void> load() async {
    if (_loaded) return;
    final repository = ref.read(readAloudSettingsRepositoryProvider);
    final generation = _generation;
    try {
      await repository.load();
      if (_isCurrent(generation)) _loaded = true;
    } finally {
      _publish(repository, generation);
    }
  }

  Future<void> _update(
    ReadAloudSettings Function(ReadAloudSettings) transform,
  ) async {
    final repository = ref.read(readAloudSettingsRepositoryProvider);
    final generation = _generation;
    await load();
    if (!_isCurrent(generation)) return;
    try {
      await repository.update(transform);
    } finally {
      _publish(repository, generation);
    }
  }

  Future<void> setContentSplit(ReadAloudSplitMode mode, String symbols) =>
      _update(
        (current) => current.copyWith(splitMode: mode, splitSymbols: symbols),
      );

  Future<void> setAudioPreDownloadNum(int value) =>
      _update((current) => current.copyWith(audioPreDownloadNum: value));

  Future<void> setTtsPreSynthesisConcurrency(int value) =>
      _update((current) => current.copyWith(ttsPreSynthesisConcurrency: value));

  Future<void> setAudioCacheCleanTime(int value) =>
      _update((current) => current.copyWith(audioCacheCleanTime: value));

  Future<void> setDetachReminder(bool value) =>
      _update((current) => current.copyWith(detachReminder: value));

  Future<void> setMediaButtonPerNext(bool value) =>
      _update((current) => current.copyWith(mediaButtonPerNext: value));

  Future<void> setFollowSystem(bool follow) =>
      _update((current) => current.copyWith(followSystem: follow));

  Future<void> setManualSpeed(double speed, {bool activateManual = false}) =>
      _update(
        (current) => current.copyWith(
          manualSpeed: speed,
          followSystem: activateManual ? false : current.followSystem,
          hasStoredManualSpeed: true,
        ),
      );

  Future<void> setParagraphInterval(int milliseconds) =>
      _update((current) => current.copyWith(paragraphIntervalMs: milliseconds));
}

final readAloudPreferencesProvider =
    NotifierProvider<ReadAloudPreferencesNotifier, ReadAloudPreferences>(
      ReadAloudPreferencesNotifier.new,
    );
