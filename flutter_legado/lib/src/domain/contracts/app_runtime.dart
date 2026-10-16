/// 应用启动与引擎信息；页面和领域仓储不承担初始化。— Codex + Bridge
abstract interface class AppRuntime {
  Future<void> initialize();
  Future<String> getVersion();
}
