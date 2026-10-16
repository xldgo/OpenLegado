import '../../bridge/rust_lib.dart' as bridge;
import '../../domain/contracts/app_runtime.dart';

/// 启动顺序由现有Bootstrap提供，版本查询使用相同FRB。— Codex + Bridge
class RustAppRuntime implements AppRuntime {
  const RustAppRuntime({required this.startup});
  final Future<void> Function() startup;
  @override
  Future<void> initialize() => startup();
  @override
  Future<String> getVersion() => bridge.version();
}
