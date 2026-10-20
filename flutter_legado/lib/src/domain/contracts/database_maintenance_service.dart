/// 数据库维护能力，不持有页面或缓存下载状态。— Codex + Bridge
abstract interface class DatabaseMaintenanceService {
  /// 返回VACUUM释放的字节数；0沿用无需压缩或Rust降级的含义。
  Future<int> shrinkDatabase();
}
