import '../../domain/contracts/audio_playback_settings_repository.dart';
import '../../domain/models/audio_playback_settings.dart';
import '../services/app_settings_service.dart';
import '../settings/app_config_settings_repository.dart';

/// 投影共享设置服务，保持原键和默认值。— Codex + UI
class AppAudioPlaybackSettingsRepository
    extends AppConfigSettingsRepository<AudioPlaybackSettings>
    implements AudioPlaybackSettingsRepository {
  AppAudioPlaybackSettingsRepository(AppSettingsService service)
    : super(service, {
        'audioPlayWakeLock',
        'audioSkipOpenCredits',
        'audioSkipCloseCredits',
      });
  @override
  AudioPlaybackSettings decode(Map<String, String?> values) =>
      AudioPlaybackSettings(
        wakeLock: values['audioPlayWakeLock'] == 'true',
        openCredits: int.tryParse(values['audioSkipOpenCredits'] ?? '') ?? 0,
        closeCredits: int.tryParse(values['audioSkipCloseCredits'] ?? '') ?? 0,
      );
  @override
  Map<String, String> encode(AudioPlaybackSettings value) => {
    'audioPlayWakeLock': value.wakeLock ? 'true' : 'false',
    'audioSkipOpenCredits': value.openCredits.toString(),
    'audioSkipCloseCredits': value.closeCredits.toString(),
  };
}
