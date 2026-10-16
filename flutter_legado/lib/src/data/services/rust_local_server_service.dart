import '../../bridge/rust_lib.dart' as bridge;
import '../../domain/contracts/local_server_service.dart';
import '../../domain/models/local_server_status.dart';
import '../bridge/rust_json_decode.dart';

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
    final map = decodeRustJsonMap(await bridge.serverStatus(), 'serverStatus');
    final running = map['running'];
    final port = map['port'];
    if (running is! bool || port is! int) {
      throw const FormatException('serverStatus缺少有效的running或port');
    }
    return LocalServerStatus(running: running, port: port);
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
