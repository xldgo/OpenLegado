/// 类型化普通设置投影，共享设置服务拥有状态与写入队列。— Codex + UI
abstract interface class SettingsRepository<T> {
  T get current;
  Stream<T> watch();
  Future<T> load();
  Future<void> reload();
  Future<void> update(T Function(T) transform);
  Future<void> settled();
}
