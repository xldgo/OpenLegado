import 'settings_repository.dart';
import '../models/service_settings.dart';

/// 服务设置访问，不暴露底层配置键。— Codex + UI
abstract interface class ServiceSettingsRepository
    implements SettingsRepository<ServiceSettings> {}
