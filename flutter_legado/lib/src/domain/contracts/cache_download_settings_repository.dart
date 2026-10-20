import '../models/cache_download_settings.dart';
import 'settings_repository.dart';

/// 离线下载配置窄接口，实际调度由Rust下载服务消费。— Codex + UI
abstract interface class CacheDownloadSettingsRepository
    implements SettingsRepository<CacheDownloadSettings> {}
