import 'settings_repository.dart';

/// 未单独配置的书籍是否默认启用替换净化；持久化由 Rust 配置拥有。— Codex + UI
abstract interface class ContentProcessingSettingsRepository
    implements SettingsRepository<bool> {}
