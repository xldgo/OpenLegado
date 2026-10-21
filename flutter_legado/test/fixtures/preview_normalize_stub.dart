import 'dart:convert';

/// [SOURCE-PARSE-FFI-20261022] 测试用预览归一化替身。
///
/// 生产实现由 Rust `sourcePreviewFields` 提供（与导入同一解析）；
/// 单测无法调用 Rust，这里做**等价最小实现**：与 Rust 口径一致的字段提取
/// （字符串标量取原样、数字/布尔取字面量、`lastUpdateTime` 认整数与整数字符串）。
/// 仅用于验证 Dart 侧编排（raw 保留、顺序、错误分支），不作为归一化规则来源。
Future<List<Map<String, dynamic>>> stubPreviewNormalize(String json) async {
  final decoded = jsonDecode(json);
  final items = decoded is List
      ? decoded
      : (decoded is Map<String, dynamic>
            ? <dynamic>[decoded]
            : throw const FormatException('预览 JSON 期望数组或对象'));

  String asString(dynamic v) {
    if (v == null) return '';
    if (v is String) return v;
    if (v is num || v is bool) return v.toString();
    return jsonEncode(v);
  }

  int asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim()) ?? 0;
    return 0;
  }

  return items.map((item) {
    if (item is! Map<String, dynamic>) {
      return <String, dynamic>{
        'bookSourceUrl': '',
        'bookSourceName': '',
        'bookSourceComment': null,
        'lastUpdateTime': 0,
      };
    }
    return <String, dynamic>{
      'bookSourceUrl': asString(item['bookSourceUrl']),
      'bookSourceName': asString(item['bookSourceName']),
      'bookSourceComment': item['bookSourceComment'] == null
          ? null
          : asString(item['bookSourceComment']),
      'lastUpdateTime': asInt(item['lastUpdateTime']),
    };
  }).toList();
}
