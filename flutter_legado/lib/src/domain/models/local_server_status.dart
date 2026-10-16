/// 进程内Web服务的真实状态，独立于设置中的启用偏好。— Codex + Bridge
class LocalServerStatus {
  const LocalServerStatus({required this.running, required this.port});

  final bool running;
  final int port;
}
