import '../bridge/rust_errors.dart';
import '../../bridge/rust_lib.dart' as bridge;
import '../../domain/contracts/config_repository.dart';

/// 保留原配置通道的空值、删除及枚举语义。— Codex + Bridge
class RustConfigRepository implements ConfigRepository {
  const RustConfigRepository();
  @override
  Future<String?> getConfig(String key) async {
    final value = await rustFuture(
      () => bridge.configGet(key: key),
      operation: 'configGet',
    );
    return value.isEmpty ? null : value;
  }

  @override
  Future<void> setConfig(String key, String value) async {
    if (!await rustFuture(
      () => bridge.configSet(key: key, value: value),
      operation: 'configSet',
    )) {
      throw StateError('配置未保存：$key');
    }
  }

  @override
  Future<void> deleteConfig(String key) => setConfig(key, '');
  @override
  Future<Map<String, String>> getAllConfigs() async {
    return rustFuture(() => bridge.configGetAll(), operation: 'configGetAll');
  }
}
