import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/contracts/read_aloud_settings_repository.dart';
import '../../features/read_aloud/read_aloud_settings_provider.dart';
import '../../platform/audio/app_audio_session.dart';

final appAudioSessionProvider = Provider<AppAudioSession>(
  (ref) => AppAudioSession.instance,
);

final audioSessionSettingsProvider = Provider<AudioSessionSettingsController>(
  (ref) => AudioSessionSettingsController(
    ref.watch(readAloudSettingsRepositoryProvider),
    ref.watch(appAudioSessionProvider),
  ),
);

/// 设置已保存，平台失败不能回报为保存失败或静默成功。— Codex + UI
final class AudioSessionPolicyException implements Exception {
  AudioSessionPolicyException(this.cause);
  final Object cause;
  @override
  String toString() => '设置已保存，但音频策略应用失败，请重新播放重试：$cause';
}

/// 启动、开关及恢复共用的装配入口；播放事实继续由原控制器拥有。
final class AudioSessionSettingsController {
  AudioSessionSettingsController(this._settings, this._session);
  final ReadAloudSettingsRepository _settings;
  final AppAudioSession _session;

  Future<void> initialize() async {
    await _settings.load();
    await _apply();
  }

  Future<void> setIgnoreAudioFocus(bool value) async {
    await _settings.update(
      (current) => current.copyWith(ignoreAudioFocus: value),
    );
    await _apply();
  }

  Future<void> reload() async {
    await _settings.reload();
    await _apply();
  }

  Future<void> _apply() async {
    try {
      await _session.setIgnoreAudioFocus(_settings.current.ignoreAudioFocus);
    } catch (error, stack) {
      Error.throwWithStackTrace(AudioSessionPolicyException(error), stack);
    }
  }
}
