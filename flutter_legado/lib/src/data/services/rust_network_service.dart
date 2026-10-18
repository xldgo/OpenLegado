import '../bridge/rust_errors.dart';
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
    final value = await rustFuture(
      () => bridge.httpGet(url: url),
      operation: 'httpGet',
    ).timeout(timeout);
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
    final value = await rustFuture(
      () => bridge.httpPost(url: url, body: body),
      operation: 'httpPost',
    ).timeout(timeout);
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
    final value = await rustFuture(
      () => bridge.httpGetBytes(
        url: url,
        headers: headers == null || headers.isEmpty ? null : headers,
      ),
      operation: 'httpGetBytes',
    ).timeout(timeout);
    return HttpBytesResponse(
      statusCode: value.status,
      bytes: value.bytes,
      url: value.url,
    );
  }

  @override
  Future<void> setCustomHosts(String configuration) => rustFuture(
    () => bridge.setCustomHosts(hostsJson: configuration),
    operation: 'setCustomHosts',
  );
  @override
  Future<void> clearCookie(String url) =>
      rustFuture(() => bridge.clearCookie(url: url), operation: 'clearCookie');
}
