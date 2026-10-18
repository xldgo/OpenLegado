import '../../domain/contracts/request_settings_repository.dart';
import '../../domain/models/request_settings.dart';
import '../services/app_settings_service.dart';
import '../settings/app_config_settings_repository.dart';

/// 仅投影Rust配置，不另存SharedPreferences或维护写入队列。— Codex + UI
final class AppRequestSettingsRepository
    extends AppConfigSettingsRepository<RequestSettings>
    implements RequestSettingsRepository {
  AppRequestSettingsRepository(AppSettingsService service)
    : super(service, {'threadCount'});

  @override
  RequestSettings decode(Map<String, String?> values) {
    final value = int.tryParse(values['threadCount']?.trim() ?? '', radix: 10);
    return RequestSettings(
      threadCount:
          value != null &&
              value >= RequestSettings.minThreadCount &&
              value <= RequestSettings.maxThreadCount
          ? value
          : RequestSettings.defaultThreadCount,
    );
  }

  @override
  Map<String, String> encode(RequestSettings value) {
    if (value.threadCount < RequestSettings.minThreadCount ||
        value.threadCount > RequestSettings.maxThreadCount) {
      throw RangeError.range(
        value.threadCount,
        RequestSettings.minThreadCount,
        RequestSettings.maxThreadCount,
        'threadCount',
      );
    }
    return {'threadCount': value.threadCount.toString()};
  }
}
