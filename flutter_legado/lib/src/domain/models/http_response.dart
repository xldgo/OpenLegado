import 'dart:typed_data';

/// 共享网络栈的文本响应；不暴露桥接传输格式。— Codex + Bridge
class HttpTextResponse {
  const HttpTextResponse({
    required this.statusCode,
    required this.body,
    this.url = '',
  });

  final int statusCode;
  final String body;
  final String url;

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
}

/// 二进制正文保持原始字节，不在消费方处理base64。
class HttpBytesResponse {
  const HttpBytesResponse({
    required this.statusCode,
    required this.bytes,
    required this.url,
  });

  final int statusCode;
  final Uint8List bytes;
  final String url;

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
}
