import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:shared_preferences/shared_preferences.dart';

import '../providers.dart';

/// 朗读偏好独立于控制条生命周期，关闭界面不改变播放参数。
class ReadAloudPreferences {
  const ReadAloudPreferences({
    this.followSystem = true,
    this.detachReminder = true,
    this.manualSpeed = 1,
    this.paragraphIntervalMs = 0,
    this.audioPreDownloadNum = 10,
    this.ttsPreSynthesisConcurrency = 3,
    this.audioCacheCleanTime = 10,
    this.loaded = false,
    this.hasStoredManualSpeed = false,
  });

  final bool followSystem;
  final bool detachReminder;
  final double manualSpeed;
  final int paragraphIntervalMs;
  final int audioPreDownloadNum,
      ttsPreSynthesisConcurrency,
      audioCacheCleanTime;
  final bool loaded;
  final bool hasStoredManualSpeed;

  /// 对齐上游跟随模式：标准倍率；不读取系统设置中的语速滑块。
  double get effectiveSpeed => followSystem ? 1 : manualSpeed;

  ReadAloudPreferences copyWith({
    bool? followSystem,
    bool? detachReminder,
    double? manualSpeed,
    int? paragraphIntervalMs,
    int? audioPreDownloadNum,
    int? ttsPreSynthesisConcurrency,
    int? audioCacheCleanTime,
    bool? loaded,
    bool? hasStoredManualSpeed,
  }) => ReadAloudPreferences(
    followSystem: followSystem ?? this.followSystem,
    detachReminder: detachReminder ?? this.detachReminder,
    manualSpeed: manualSpeed ?? this.manualSpeed,
    paragraphIntervalMs: paragraphIntervalMs ?? this.paragraphIntervalMs,
    audioPreDownloadNum: audioPreDownloadNum ?? this.audioPreDownloadNum,
    ttsPreSynthesisConcurrency:
        ttsPreSynthesisConcurrency ?? this.ttsPreSynthesisConcurrency,
    audioCacheCleanTime: audioCacheCleanTime ?? this.audioCacheCleanTime,
    loaded: loaded ?? this.loaded,
    hasStoredManualSpeed: hasStoredManualSpeed ?? this.hasStoredManualSpeed,
  );
}

class ReadAloudPreferencesNotifier extends Notifier<ReadAloudPreferences> {
  Future<void>? _loading;
  Future<void> _writes = Future.value();

  @override
  ReadAloudPreferences build() => const ReadAloudPreferences();

  Future<void> load() {
    if (state.loaded) return Future.value();
    return _loading ??= _load().whenComplete(() => _loading = null);
  }

  Future<void> _load() async {
    final api = ref.read(bookApiProvider);
    final values = await Future.wait([
      api.getConfig('ttsFollowSys'),
      api.getConfig('ttsSpeechRate'),
      api.getConfig('ttsParagraphInterval'),
      api.getConfig('readAloudDetachReminderEnabled'),
      api.getConfig('audioPreDownloadNum'),
      api.getConfig('ttsPreSynthesisConcurrency'),
      api.getConfig('audioCacheCleanTime'),
    ]);
    var follow = values[0];
    // 沿用原有偏好迁移，不因更换界面丢失用户选择。
    if (follow == null || follow.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getBool('read_aloud_follow_system_speed');
      if (legacy != null) {
        follow = legacy ? 'true' : 'false';
        await api.setConfig('ttsFollowSys', follow);
        await prefs.remove('read_aloud_follow_system_speed');
      }
    }
    if (!ref.mounted) return;
    final rate = int.tryParse(values[1] ?? '') ?? 5;
    state = ReadAloudPreferences(
      detachReminder: values[3] != 'false' && values[3] != '0',
      followSystem:
          follow == null || follow.isEmpty || follow == 'true' || follow == '1',
      manualSpeed: ((rate + 5) / 10).clamp(0.5, 3),
      paragraphIntervalMs: (int.tryParse(values[2] ?? '') ?? 0).clamp(0, 5000),
      audioPreDownloadNum: (int.tryParse(values[4] ?? '') ?? 10).clamp(0, 100),
      ttsPreSynthesisConcurrency: (int.tryParse(values[5] ?? '') ?? 3).clamp(
        1,
        8,
      ),
      audioCacheCleanTime: (int.tryParse(values[6] ?? '') ?? 10).clamp(0, 1440),
      loaded: true,
      hasStoredManualSpeed: values[1] != null && values[1]!.isNotEmpty,
    );
  }

  /// 写入串行化；保存失败不报告成功，也不让较早写入覆盖后来的选择。
  Future<void> _save(
    String key,
    String value,
    ReadAloudPreferences Function() update,
  ) {
    final api = ref.read(bookApiProvider);
    final operation = _writes.catchError((Object _) {}).then((_) async {
      await api.setConfig(key, value);
      if (ref.mounted) state = update();
    });
    _writes = operation;
    return operation;
  }

  Future<void> setAudioPreDownloadNum(int value) async {
    await load();
    final n = value.clamp(0, 100);
    await _save(
      'audioPreDownloadNum',
      '$n',
      () => state.copyWith(audioPreDownloadNum: n),
    );
  }

  Future<void> setTtsPreSynthesisConcurrency(int value) async {
    await load();
    final n = value.clamp(1, 8);
    await _save(
      'ttsPreSynthesisConcurrency',
      '$n',
      () => state.copyWith(ttsPreSynthesisConcurrency: n),
    );
  }

  Future<void> setAudioCacheCleanTime(int value) async {
    await load();
    final n = value.clamp(0, 1440);
    await _save(
      'audioCacheCleanTime',
      '$n',
      () => state.copyWith(audioCacheCleanTime: n),
    );
  }

  Future<void> setDetachReminder(bool value) async {
    await load();
    await _save(
      'readAloudDetachReminderEnabled',
      '$value',
      () => state.copyWith(detachReminder: value),
    );
  }

  Future<void> setFollowSystem(bool follow) async {
    await load();
    await _save(
      'ttsFollowSys',
      '$follow',
      () => state.copyWith(followSystem: follow),
    );
  }

  Future<void> setManualSpeed(double speed) async {
    await load();
    final rate = (speed.clamp(0.5, 3) * 10 - 5).round();
    await _save(
      'ttsSpeechRate',
      '$rate',
      () => state.copyWith(
        manualSpeed: (rate + 5) / 10,
        hasStoredManualSpeed: true,
      ),
    );
  }

  Future<void> setParagraphInterval(int milliseconds) async {
    await load();
    final interval = milliseconds.clamp(0, 5000);
    await _save(
      'ttsParagraphInterval',
      '$interval',
      () => state.copyWith(paragraphIntervalMs: interval),
    );
  }
}

final readAloudPreferencesProvider =
    NotifierProvider<ReadAloudPreferencesNotifier, ReadAloudPreferences>(
      ReadAloudPreferencesNotifier.new,
    );
