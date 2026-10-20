import '../../domain/contracts/service_settings_repository.dart';
import '../../domain/models/service_settings.dart';
import '../services/app_settings_service.dart';
import '../settings/app_config_settings_repository.dart';

/// 投影共享设置服务，保持原键和默认值。— Codex + UI
class AppServiceSettingsRepository
    extends AppConfigSettingsRepository<ServiceSettings>
    implements ServiceSettingsRepository {
  AppServiceSettingsRepository(AppSettingsService service)
    : super(service, {
        'webService',
        'autoTaskService',
        'mcpPort',
        'customHosts',
      });
  @override
  ServiceSettings decode(Map<String, String?> values) => ServiceSettings(
    webEnabled: values['webService'] == 'true',
    autoTaskEnabled: values['autoTaskService'] == 'true',
    mcpPort: int.tryParse(values['mcpPort'] ?? '') ?? 0,
    customHosts: values['customHosts'] ?? '',
  );
  @override
  Map<String, String> encode(ServiceSettings value) => {
    'webService': value.webEnabled ? 'true' : 'false',
    'autoTaskService': value.autoTaskEnabled ? 'true' : 'false',
    'mcpPort': value.mcpPort.toString(),
    'customHosts': value.customHosts,
  };
}
