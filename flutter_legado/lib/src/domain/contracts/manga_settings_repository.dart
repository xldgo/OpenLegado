import 'settings_repository.dart';
import '../models/manga_settings.dart';

/// 漫画设置访问，不暴露底层配置键。— Codex + UI
abstract interface class MangaSettingsRepository
    implements SettingsRepository<MangaSettings> {}
