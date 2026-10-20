/// 平台安全存储拥有凭据，数据库仅持有版本化引用。— Codex + Bridge
abstract interface class CloudTtsCredentialStore {
  Future<String?> read(String key);
  Future<void> write(String key, String apiKey);
  Future<void> delete(String key);
}
