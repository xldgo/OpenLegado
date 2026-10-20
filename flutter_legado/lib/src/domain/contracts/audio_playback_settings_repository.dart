import 'settings_repository.dart';
import '../models/audio_playback_settings.dart';

/// 音频播放设置访问，不暴露底层配置键。— Codex + UI
abstract interface class AudioPlaybackSettingsRepository
    implements SettingsRepository<AudioPlaybackSettings> {}
