import 'dart:convert';
import 'dart:typed_data';

import '../../domain/contracts/network_service.dart';
import '../../domain/models/http_response.dart';

/// 无真实请求，hosts与宿主配置共享；保留原Mock校验语义。— Codex + Bridge
class MockNetworkService implements NetworkService {
  MockNetworkService({required this._configs});

  final Map<String, String> _configs;

  @override
  Future<HttpTextResponse> httpGet(
    String url, {
    Duration timeout = const Duration(seconds: 30),
  }) async => HttpTextResponse(statusCode: 200, body: '', url: url);

  @override
  Future<HttpTextResponse> httpPost(
    String url,
    String body, {
    Duration timeout = const Duration(seconds: 30),
  }) async => HttpTextResponse(
    statusCode: 200,
    body: '{"status":"ok","mock":true}',
    url: url,
  );

  @override
  Future<HttpBytesResponse> httpGetBytes(
    String url, {
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 30),
  }) async => HttpBytesResponse(statusCode: 200, bytes: Uint8List(0), url: url);

  @override
  Future<void> setCustomHosts(String configuration) async {
    final trimmed = configuration.trim();
    if (trimmed.isNotEmpty && jsonDecode(trimmed) is! Map) {
      throw const FormatException('customHosts必须为JSON对象');
    }
    _configs['customHosts'] = configuration;
  }
}
