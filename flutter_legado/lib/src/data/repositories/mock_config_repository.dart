import '../../domain/contracts/config_repository.dart';

/// 与同一Mock装配中的其他能力共享Map，不模拟SQLite。— Codex + Bridge
class MockConfigRepository implements ConfigRepository {
  MockConfigRepository({Map<String, String>? values}) : _values = values ?? {};
  final Map<String, String> _values;
  @override
  Future<String?> getConfig(String key) async => _values[key];
  @override
  Future<void> setConfig(String key, String value) async =>
      _values[key] = value;
  @override
  Future<void> deleteConfig(String key) async => _values.remove(key);
  @override
  Future<Map<String, String>> getAllConfigs() async => Map.of(_values);
}
