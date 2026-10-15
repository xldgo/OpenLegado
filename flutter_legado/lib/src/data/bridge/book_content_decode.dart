import 'dart:convert';

import '../../domain/models/book_content_result.dart';
import '../../domain/models/review.dart';
import 'rust_api_exception.dart';
import 'rust_json_decode.dart';

/// 书籍内容传输数据只在数据层解析，不以空结果掩盖坏响应。— Codex + Bridge
String contentString(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is String) return value;
  throw FormatException('书籍内容字段$key不是字符串');
}

List<String> contentStrings(dynamic value) {
  if (value is List && value.every((item) => item is String)) {
    return value.cast<String>();
  }
  throw const FormatException('书籍内容响应不是字符串列表');
}

Map<String, dynamic> successfulContent(String json, String operation) {
  final map = decodeRustJsonMap(json, operation);
  if (map['success'] is! bool) throw FormatException('$operation缺少成功标记');
  if (map['success'] != true) {
    throw RustApiException(
      map['error'] as String? ?? '$operation失败',
      operation: operation,
    );
  }
  return map;
}

BookExportData decodeBookExport(String json) {
  final map = successfulContent(json, 'bookExport');
  return BookExportData(
    fileName: contentString(map, 'file_name'),
    bytes: base64Decode(contentString(map, 'data_base64')),
    mimeType: contentString(map, 'mime_type'),
  );
}

BookExportInfo decodeBookExportInfo(String json) {
  final map = successfulContent(json, 'bookExportInfo');
  // 当前Rust把章节数放在成功响应的error字段；仅适配当前协议，不向UI泄漏。
  final match = RegExp(r'^章节数[:：]\s*(\d+)$')
      .firstMatch(contentString(map, 'error'));
  if (match == null) throw const FormatException('导出预览缺少有效章节数');
  return BookExportInfo(
    fileName: contentString(map, 'file_name'),
    chapterCount: int.parse(match[1]!),
  );
}

ReviewSummary decodeReviewSummary(String json) {
  final map = decodeRustJsonMap(json, 'reviewGetSummary');
  if (map['counts'] is! Map || map['keys'] is! Map) {
    throw const FormatException('段评摘要结构无效');
  }
  final counts = <int, int>{};
  for (final entry in (map['counts'] as Map).entries) {
    final index = int.tryParse(entry.key.toString());
    if (index == null || entry.value is! int) {
      throw const FormatException('段评数量无效');
    }
    if ((entry.value as int) > 0) counts[index] = entry.value as int;
  }
  final keys = <int, String>{};
  for (final entry in (map['keys'] as Map).entries) {
    final index = int.tryParse(entry.key.toString());
    if (index == null || entry.value is! String) {
      throw const FormatException('段评标识无效');
    }
    keys[index] = entry.value as String;
  }
  return ReviewSummary(counts: counts, keys: keys);
}

ReviewPage decodeReviewPage(String json) {
  final map = decodeRustJsonMap(json, 'reviewPage');
  if (map['nextPageUrl'] != null && map['nextPageUrl'] is! String ||
      map['hasReplyUrl'] != null && map['hasReplyUrl'] is! bool) {
    throw const FormatException('段评分页字段无效');
  }
  ReviewDetailItem parseItem(dynamic value) {
    if (value is! Map<String, dynamic>) throw const FormatException('段评条目无效');
    if (value['replies'] != null) {
      if (value['replies'] is! List) throw const FormatException('段评回复结构无效');
      for (final reply in value['replies'] as List) {
        parseItem(reply);
      }
    }
    return ReviewDetailItem.fromJson(value);
  }

  final items = map['items'];
  if (items is! List) throw const FormatException('段评列表结构无效');
  return ReviewPage(
    items: items.map(parseItem).toList(),
    nextPageUrl: map['nextPageUrl'] as String?,
    hasReplyUrl: map['hasReplyUrl'] == true,
  );
}
