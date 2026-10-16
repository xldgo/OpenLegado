import '../models/http_response.dart';

/// 使用宿主共享客户端，沿用Cookie、UA、超时和DNS配置。— Codex + Bridge
abstract interface class NetworkService {
  Future<HttpTextResponse> httpGet(
    String url, {
    Duration timeout = const Duration(seconds: 30),
  });

  Future<HttpTextResponse> httpPost(
    String url,
    String body, {
    Duration timeout = const Duration(seconds: 30),
  });

  Future<HttpBytesResponse> httpGetBytes(
    String url, {
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 30),
  });

  /// 使用现有hosts编辑格式；空文本恢复系统DNS，失败不持久化。
  Future<void> setCustomHosts(String configuration);
}
