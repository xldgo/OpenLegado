import 'settings_repository.dart';
import '../models/change_source_settings.dart';

/// 换源设置访问，不暴露底层配置键。— Codex + UI
abstract interface class ChangeSourceSettingsRepository
    implements SettingsRepository<ChangeSourceSettings> {}
