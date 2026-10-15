import '../bridge/rust_json_decode.dart';

/// RSS返回载荷统一在数据边界解析；坏条目不得丢弃或冒充空列表。— Codex + Bridge
List<T> decodeRssList<T>(
  String json,
  String operation,
  T Function(Map<String, dynamic>) decode,
) => decodeRustJsonList(json, operation).indexed.map((entry) {
  final (index, value) = entry;
  if (value is! Map<String, dynamic>) {
    throw FormatException('$operation：第${index + 1}项必须是对象');
  }
  return decodeRssObject(value, '$operation：第${index + 1}项', decode);
}).toList();

T decodeRssObject<T>(
  Map<String, dynamic> value,
  String operation,
  T Function(Map<String, dynamic>) decode,
) {
  try {
    return decode(value);
  } catch (error) {
    throw FormatException('$operation：字段无效（$error）');
  }
}
