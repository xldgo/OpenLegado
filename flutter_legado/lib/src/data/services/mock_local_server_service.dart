import '../../domain/contracts/local_server_service.dart';
import '../../domain/models/local_server_status.dart';

/// 只记录内存状态，不绑定端口；与根配置访问共享同一存储。— Codex + Bridge
class MockLocalServerService implements LocalServerService {
  MockLocalServerService({required this._configs});

  final Map<String, String> _configs;

  @override
  Future<void> startServer({int port = 1122}) async {
    _configs['server_port'] = port.toString();
    _configs['server_running'] = 'true';
  }

  @override
  Future<void> stopServer() async => _configs['server_running'] = 'false';

  @override
  Future<LocalServerStatus> getServerStatus() async => LocalServerStatus(
    running: _configs['server_running'] == 'true',
    port: int.tryParse(_configs['server_port'] ?? '') ?? 1122,
  );

  @override
  Future<void> setServerPort(int port) async =>
      _configs['server_port'] = port.toString();

  @override
  Future<void> setMcpPort(int port) async {
    if (port > 0 && (port < 1024 || port > 65530)) {
      throw ArgumentError.value(port, 'port', 'MCP端口范围为1024..65530');
    }
    _configs['mcpPort'] = port.toString();
  }
}
