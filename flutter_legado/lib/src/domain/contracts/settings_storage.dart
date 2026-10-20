/// 普通设置底层读写；不存在为 null，失败抛错，不承诺跨键事务。— Codex + UI
abstract interface class SettingsStorage {
  Future<Object?> read(String key);
  Future<void> write(String key, Object? value);
}
