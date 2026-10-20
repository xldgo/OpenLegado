import '../models/download_settings.dart';
import 'settings_repository.dart';

/// 页面与阅读预取共享偏好，具体存储由数据层装配。— Codex + UI
abstract interface class DownloadSettingsRepository
    implements SettingsRepository<DownloadSettings> {}
