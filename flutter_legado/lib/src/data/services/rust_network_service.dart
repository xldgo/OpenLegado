import 'dart:convert';

import '../../bridge/rust_lib.dart' as bridge;
import '../../domain/contracts/network_service.dart';
import '../../domain/models/http_response.dart';
import '../bridge/rust_json_decode.dart';

/// JSON/base64传输仅在适配器处理，网络行为由Rust共享客户端负责。— Codex + Bridge
class RustNetworkService implements NetworkService {
  const RustNetworkService();

  @override
  Future<HttpTextResponse> httpGet(
    String url, {
    Duration timeout = const Duration(seconds: 30),
  }) async => _textResponse(
    await bridge.httpGet(url: url).timeout(timeout),
    url,
    'httpGet',
  );

  @override
  Future<HttpTextResponse> httpPost(
    String url,
    String body, {
    Duration timeout = const Duration(seconds: 30),
  }) async => _textResponse(
    await bridge.httpPost(url: url, body: body).timeout(timeout),
    url,
    'httpPost',
  );

  @override
  Future<HttpBytesResponse> httpGetBytes(
    String url, {
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final raw = await bridge
        .httpGetBytes(
          url: url,
          headersJson: headers == null || headers.isEmpty
              ? ''
              : jsonEncode(headers),
        )
        .timeout(timeout);
    final map = decodeRustJsonMap(raw, 'httpGetBytes');
    final body = map['bodyBase64'];
    if (body is! String) {
      throw const FormatException('httpGetBytes缺少有效的bodyBase64');
    }
    return HttpBytesResponse(
      statusCode: _status(map, 'httpGetBytes'),
      bytes: base64Decode(body),
      url: _url(map, url, 'httpGetBytes'),
    );
  }

  @override
  Future<void> setCustomHosts(String configuration) =>
      bridge.setCustomHosts(hostsJson: configuration);
}

HttpTextResponse _textResponse(String raw, String url, String method) {
  final map = decodeRustJsonMap(raw, method);
  final body = map['body'];
  if (body is! String) throw FormatException('$method缺少有效的body');
  return HttpTextResponse(
    statusCode: _status(map, method),
    body: body,
    url: _url(map, url, method),
  );
}

int _status(Map<String, dynamic> map, String method) {
  final value = map['status'];
  if (value is! int) throw FormatException('$method缺少有效的status');
  return value;
}

String _url(Map<String, dynamic> map, String fallback, String method) {
  final value = map['url'];
  if (value == null) return fallback;
  if (value is! String) throw FormatException('$method的url不是字符串');
  return value;
}
