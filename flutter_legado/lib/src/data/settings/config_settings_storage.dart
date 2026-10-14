import '../../domain/contracts/settings_storage.dart';

/// 绑定同一根配置访问，迁移期与旧消费者及 Mock 共享存储。— Codex + UI
final class ConfigSettingsStorage implements SettingsStorage {
  const ConfigSettingsStorage({required this._read, required this._write});

  final Future<String?> Function(String) _read;
  final Future<void> Function(String, String) _write;

  @override
  Future<Object?> read(String key) => _read(key);

  @override
  Future<void> write(String key, Object? value) {
    if (value != null && value is! String) {
      throw ArgumentError('Rust 配置要求字符串值：$key');
    }
    return _write(key, value as String? ?? '');
  }
}
