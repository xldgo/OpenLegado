import '../../domain/contracts/service_settings_repository.dart';
import '../../domain/models/service_settings.dart';
import '../services/app_settings_service.dart';
import '../settings/app_config_settings_repository.dart';

/// 服务配置与运行状态分开，自动启动只保存下次冷启动意图。— Codex + UI
class AppServiceSettingsRepository
    extends AppConfigSettingsRepository<ServiceSettings>
    implements ServiceSettingsRepository {
  AppServiceSettingsRepository(AppSettingsService service)
    : super(service, {
        'webServiceAutoStart',
        'autoTaskService',
        'mcpPort',
        'customHosts',
      });
  @override
  ServiceSettings decode(Map<String, String?> values) => ServiceSettings(
    webAutoStart: values['webServiceAutoStart'] == 'true',
    autoTaskEnabled: values['autoTaskService'] == 'true',
    mcpPort: int.tryParse(values['mcpPort'] ?? '') ?? 0,
    customHosts: values['customHosts'] ?? '',
  );
  @override
  Map<String, String> encode(ServiceSettings value) => {
    'webServiceAutoStart': value.webAutoStart ? 'true' : 'false',
    'autoTaskService': value.autoTaskEnabled ? 'true' : 'false',
    'mcpPort': value.mcpPort.toString(),
    'customHosts': value.customHosts,
  };
}
