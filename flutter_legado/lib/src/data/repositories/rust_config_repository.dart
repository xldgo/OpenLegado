import '../../bridge/rust_lib.dart' as bridge;
import '../../domain/contracts/config_repository.dart';
import '../bridge/rust_json_decode.dart';

/// 保留原配置通道的空值、删除及枚举语义。— Codex + Bridge
class RustConfigRepository implements ConfigRepository {
  const RustConfigRepository();
  @override
  Future<String?> getConfig(String key) async {
    final value = await bridge.configGet(key: key);
    return value.isEmpty ? null : value;
  }

  @override
  Future<void> setConfig(String key, String value) async {
    if (!await bridge.configSet(key: key, value: value)) {
      throw StateError('配置未保存：$key');
    }
  }

  @override
  Future<void> deleteConfig(String key) => setConfig(key, '');
  @override
  Future<Map<String, String>> getAllConfigs() async {
    final values = decodeRustJsonMap(
      await bridge.configGetAll(),
      'configGetAll',
    );
    return values.map((key, value) => MapEntry(key, value.toString()));
  }
}
