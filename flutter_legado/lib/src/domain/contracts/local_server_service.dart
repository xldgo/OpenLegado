import '../models/local_server_status.dart';

/// Web与MCP服务控制，不负责UI偏好、平台保活或自动启动。— Codex + Bridge
abstract interface class LocalServerService {
  Future<void> startServer({int port = 1122});
  Future<void> stopServer();
  Future<LocalServerStatus> getServerStatus();

  /// 保存Web端口，下次启动生效。
  Future<void> setServerPort(int port);

  /// 正数启动或重启独立MCP服务，非正数停止；错误由底层返回。
  Future<void> setMcpPort(int port);
}
