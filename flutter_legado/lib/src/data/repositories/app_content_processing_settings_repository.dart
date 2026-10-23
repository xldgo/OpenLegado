import '../../domain/contracts/content_processing_settings_repository.dart';
import '../services/app_settings_service.dart';
import '../settings/app_config_settings_repository.dart';

/// 共用设置队列和 RustConfig 存储，不读取或双写旧偏好。— Codex + UI
final class AppContentProcessingSettingsRepository
    extends AppConfigSettingsRepository<bool>
    implements ContentProcessingSettingsRepository {
  AppContentProcessingSettingsRepository(AppSettingsService service)
    : super(service, {'replaceEnableDefault'});

  @override
  bool decode(Map<String, String?> values) =>
      values['replaceEnableDefault'] != 'false';
  @override
  Map<String, String> encode(bool value) => {'replaceEnableDefault': '$value'};
}
