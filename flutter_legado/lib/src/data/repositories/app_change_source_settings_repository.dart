import '../../domain/contracts/change_source_settings_repository.dart';
import '../../domain/models/change_source_settings.dart';
import '../services/app_settings_service.dart';
import '../settings/app_config_settings_repository.dart';

/// 投影共享设置服务，保持原键和默认值。— Codex + UI
class AppChangeSourceSettingsRepository
    extends AppConfigSettingsRepository<ChangeSourceSettings>
    implements ChangeSourceSettingsRepository {
  AppChangeSourceSettingsRepository(AppSettingsService service)
    : super(service, {
        'changeSourceCheckAuthor',
        'changeSourceLoadWordCount',
        'changeSourceLoadInfo',
        'changeSourceLoadToc',
      });
  @override
  ChangeSourceSettings decode(Map<String, String?> values) =>
      ChangeSourceSettings(
        checkAuthor: values['changeSourceCheckAuthor'] == 'true',
        loadWordCount: values['changeSourceLoadWordCount'] == 'true',
        loadInfo: values['changeSourceLoadInfo'] == 'true',
        loadToc: values['changeSourceLoadToc'] == 'true',
      );
  @override
  Map<String, String> encode(ChangeSourceSettings value) => {
    'changeSourceCheckAuthor': value.checkAuthor ? 'true' : 'false',
    'changeSourceLoadWordCount': value.loadWordCount ? 'true' : 'false',
    'changeSourceLoadInfo': value.loadInfo ? 'true' : 'false',
    'changeSourceLoadToc': value.loadToc ? 'true' : 'false',
  };
}
