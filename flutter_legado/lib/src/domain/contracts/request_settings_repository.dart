import '../models/request_settings.dart';
import 'settings_repository.dart';

/// 网络并发设置的窄接口，配置存储由共享服务负责。— Codex + UI
abstract interface class RequestSettingsRepository
    implements SettingsRepository<RequestSettings> {}
