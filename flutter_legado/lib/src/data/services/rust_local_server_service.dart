import '../../bridge/rust_lib.dart' as bridge;
import '../../domain/contracts/local_server_service.dart';
import '../../domain/models/local_server_status.dart';

/// 不复制Rust服务状态机，状态读取失败由调用方处理。— Codex + Bridge
class RustLocalServerService implements LocalServerService {
  const RustLocalServerService();

  @override
  Future<void> startServer({int port = 1122}) async {
    await bridge.serverStart(port: port);
  }

  @override
  Future<void> stopServer() async {
    await bridge.serverStop();
  }

  @override
  Future<LocalServerStatus> getServerStatus() async {
    final status = await bridge.serverStatus();
    return LocalServerStatus(running: status.running, port: status.port);
  }

  @override
  Future<void> setServerPort(int port) async {
    if (!await bridge.configSet(key: 'server_port', value: port.toString())) {
      throw StateError('Web服务端口保存失败');
    }
  }

  @override
  Future<void> setMcpPort(int port) => bridge.setMcpPort(port: port);
}
