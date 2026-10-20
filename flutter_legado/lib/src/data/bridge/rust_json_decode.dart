import 'dart:convert';

/// 共用现有 Rust JSON 解码守卫，保留格式错误的上下文。— Codex + Bridge
List<dynamic> decodeRustJsonList(String json, String method) {
  final dynamic decoded = jsonDecode(json);
  if (decoded is List<dynamic>) return decoded;
  throw FormatException(
    '$method（Rust JSON 列表解码）: 期望 JSON 数组，实际为 ${decoded.runtimeType}，'
    '原始内容前 120 字符：${json.length > 120 ? json.substring(0, 120) : json}',
  );
}

/// 共用对象解码；不将错误结构当作空结果。
Map<String, dynamic> decodeRustJsonMap(String json, String method) {
  final dynamic decoded = jsonDecode(json);
  if (decoded is Map<String, dynamic>) return decoded;
  if (decoded is Map) return decoded.cast<String, dynamic>();
  throw FormatException(
    '$method（Rust JSON 对象解码）: 期望 JSON 对象，实际为 ${decoded.runtimeType}，'
    '原始内容前 120 字符：${json.length > 120 ? json.substring(0, 120) : json}',
  );
}
