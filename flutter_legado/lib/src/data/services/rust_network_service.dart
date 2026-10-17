import '../../bridge/rust_lib.dart' as bridge;
import '../../domain/contracts/network_service.dart';
import '../../domain/models/http_response.dart';

/// 响应字段与字节直接映射，网络能力仍由宿主客户端负责。— Codex + Bridge
class RustNetworkService implements NetworkService {
  const RustNetworkService();
  @override
  Future<HttpTextResponse> httpGet(
    String url, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final value = await bridge.httpGet(url: url).timeout(timeout);
    return HttpTextResponse(
      statusCode: value.status,
      body: value.body,
      url: value.url,
    );
  }

  @override
  Future<HttpTextResponse> httpPost(
    String url,
    String body, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final value = await bridge.httpPost(url: url, body: body).timeout(timeout);
    return HttpTextResponse(
      statusCode: value.status,
      body: value.body,
      url: value.url,
    );
  }

  @override
  Future<HttpBytesResponse> httpGetBytes(
    String url, {
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final value = await bridge
        .httpGetBytes(
          url: url,
          headers: headers == null || headers.isEmpty ? null : headers,
        )
        .timeout(timeout);
    return HttpBytesResponse(
      statusCode: value.status,
      bytes: value.bytes,
      url: value.url,
    );
  }

  @override
  Future<void> setCustomHosts(String configuration) =>
      bridge.setCustomHosts(hostsJson: configuration);
  @override
  Future<void> clearCookie(String url) => bridge.clearCookie(url: url);
}
