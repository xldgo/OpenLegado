import '../../domain/contracts/cache_download_settings_repository.dart';
import '../../domain/models/cache_download_settings.dart';
import '../services/app_settings_service.dart';
import '../settings/app_config_settings_repository.dart';

/// 单源投影Rust下载配置，不在SharedPreferences保存第二份值。— Codex + UI
final class AppCacheDownloadSettingsRepository
    extends AppConfigSettingsRepository<CacheDownloadSettings>
    implements CacheDownloadSettingsRepository {
  AppCacheDownloadSettingsRepository(AppSettingsService service)
    : super(service, {'cacheBookThreadCount'});

  @override
  CacheDownloadSettings decode(Map<String, String?> values) {
    final count = int.tryParse(
      values['cacheBookThreadCount']?.trim() ?? '',
      radix: 10,
    );
    return CacheDownloadSettings(
      threadCount:
          count != null &&
              count >= CacheDownloadSettings.minThreadCount &&
              count <= CacheDownloadSettings.maxThreadCount
          ? count
          : CacheDownloadSettings.defaultThreadCount,
    );
  }

  @override
  Map<String, String> encode(CacheDownloadSettings value) {
    RangeError.checkValueInInterval(
      value.threadCount,
      CacheDownloadSettings.minThreadCount,
      CacheDownloadSettings.maxThreadCount,
      'threadCount',
    );
    return {'cacheBookThreadCount': '${value.threadCount}'};
  }
}
