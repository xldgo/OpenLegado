/// Rust配置通道的底层存储；领域默认值和业务键由对应仓储解释。— Codex + Bridge
abstract interface class ConfigRepository {
  Future<String?> getConfig(String key);
  Future<void> setConfig(String key, String value);
  Future<void> deleteConfig(String key);
  Future<Map<String, String>> getAllConfigs();
}
