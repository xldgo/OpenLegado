/// 连接测试结果；协议判定由远程服务负责，界面只展示分类。— Codex + UI
enum WebDavProbeStatus {
  success,
  authenticationFailed,
  httpFailed,
  timedOut,
  networkFailed,
  invalidUrl,
}

final class WebDavProbeResult {
  const WebDavProbeResult(this.status, {this.statusCode});

  final WebDavProbeStatus status;
  final int? statusCode;
}
