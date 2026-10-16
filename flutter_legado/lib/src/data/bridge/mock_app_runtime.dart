import '../../domain/contracts/app_runtime.dart';

/// 初始化仍预热原Mock资产，不加载原生库。— Codex + Bridge
class MockAppRuntime implements AppRuntime {
  const MockAppRuntime({required this.startup});
  final Future<void> Function() startup;
  @override
  Future<void> initialize() => startup();
  @override
  Future<String> getVersion() async => 'mock-1.0.0';
}
