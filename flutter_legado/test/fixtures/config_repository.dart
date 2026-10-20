import 'package:flutter_legado/src/domain/contracts/config_repository.dart';

/// 领域行为夹具显式注入配置读写，不再覆盖根API方法。— Codex + Bridge
class TestConfigRepository implements ConfigRepository {
  TestConfigRepository({required this.read, this.write, this.remove});
  final Future<String?> Function(String) read;
  final Future<void> Function(String, String)? write;
  final Future<void> Function(String)? remove;
  @override
  Future<String?> getConfig(String key) => read(key);
  @override
  Future<void> setConfig(String key, String value) =>
      write?.call(key, value) ?? Future.value();
  @override
  Future<void> deleteConfig(String key) =>
      remove?.call(key) ?? setConfig(key, '');
  @override
  Future<Map<String, String>> getAllConfigs() async => {};
}
