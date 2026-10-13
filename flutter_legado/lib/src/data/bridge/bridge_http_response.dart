import 'dart:convert';

/// Rust 文本 GET 响应的共同解析规则。— Codex + Bridge
class BridgeHttpResponse {
  const BridgeHttpResponse({
    required this.statusCode,
    required this.body,
    this.url = '',
  });

  factory BridgeHttpResponse.fromJson(String raw, {String fallbackUrl = ''}) {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return BridgeHttpResponse(
      statusCode: map['status'] as int? ?? 0,
      body: map['body'] as String? ?? '',
      url: map['url'] as String? ?? fallbackUrl,
    );
  }

  final int statusCode;
  final String body;
  final String url;

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
}
