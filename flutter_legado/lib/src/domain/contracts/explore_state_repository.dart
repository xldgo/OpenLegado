/// 书源infoMap的共享访问；默认值不能覆盖已保存值。— Codex + Bridge
abstract interface class ExploreStateRepository {
  Future<void> put(String sourceUrl, String key, String value);
  Future<void> ensureDefault(String sourceUrl, String key, String defaultValue);
  Future<Map<String, String>> snapshot(String sourceUrl);
}
