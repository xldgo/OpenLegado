import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:shared_preferences/shared_preferences.dart';

import '../providers.dart';

/// 朗读偏好独立于控制条生命周期，关闭界面不改变播放参数。
class ReadAloudPreferences {
  const ReadAloudPreferences({
    this.followSystem = true,
    this.manualSpeed = 1,
    this.paragraphIntervalMs = 0,
    this.loaded = false,
    this.hasStoredManualSpeed = false,
  });

  final bool followSystem;
  final double manualSpeed;
  final int paragraphIntervalMs;
  final bool loaded;
  final bool hasStoredManualSpeed;

  /// 对齐上游跟随模式：标准倍率；不读取系统设置中的语速滑块。
  double get effectiveSpeed => followSystem ? 1 : manualSpeed;

  ReadAloudPreferences copyWith({
    bool? followSystem,
    double? manualSpeed,
    int? paragraphIntervalMs,
    bool? loaded,
    bool? hasStoredManualSpeed,
  }) => ReadAloudPreferences(
    followSystem: followSystem ?? this.followSystem,
    manualSpeed: manualSpeed ?? this.manualSpeed,
    paragraphIntervalMs: paragraphIntervalMs ?? this.paragraphIntervalMs,
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
      followSystem:
          follow == null || follow.isEmpty || follow == 'true' || follow == '1',
      manualSpeed: ((rate + 5) / 10).clamp(0.5, 3),
      paragraphIntervalMs: (int.tryParse(values[2] ?? '') ?? 0).clamp(0, 5000),
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
