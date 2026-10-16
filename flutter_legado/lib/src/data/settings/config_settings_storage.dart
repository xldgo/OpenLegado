import '../../domain/contracts/settings_storage.dart';
import '../../domain/contracts/config_repository.dart';

/// 延迟绑定配置仓储，启动预热不提前访问尚未打开的数据库。— Codex + UI
final class ConfigSettingsStorage implements SettingsStorage {
  const ConfigSettingsStorage({required this.repository});

  final ConfigRepository Function() repository;

  @override
  Future<Object?> read(String key) => repository().getConfig(key);

  @override
  Future<void> write(String key, Object? value) {
    if (value != null && value is! String) {
      throw ArgumentError('Rust 配置要求字符串值：$key');
    }
    return repository().setConfig(key, value as String? ?? '');
  }
}
