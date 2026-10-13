import 'dart:convert';

import '../models/source_preview.dart';

/// 书源预览解析及轻量校验，不访问网络、文件或数据库。— Codex + UI
class SourceImportParser {
  const SourceImportParser();

  /// 保留原始条目类型；非法 JSON 抛异常，非对象/数组返回 null。
  List<dynamic>? decodeSources(String text) {
    final decoded = jsonDecode(text);
    if (decoded is List) return decoded;
    if (decoded is Map<String, dynamic>) return [decoded];
    return null;
  }

  /// 解析书源 JSON 文本为预览条目列表（仅预览，不写入数据库）
  ///
  /// 支持单个书源对象或书源数组。不做严格 freezed 类型化解析（第三方书源
  /// 的字符串数字/字符串布尔字段会抛 TypeError），仅轻量提取展示字段；
  /// 原始 JSON 保留到 [SourcePreview.raw]，确认导入时直传 Rust 兜底。
  /// 失败项累计计数，全部失败时抛出携带首个错误信息的 FormatException。
  List<SourcePreview> parseSourcesText(String jsonStr) {
    final sourceList = decodeSources(jsonStr.trim());
    if (sourceList == null) {
      throw const FormatException('无效的 JSON 格式：期望数组或对象');
    }

    final sources = <SourcePreview>[];
    var failed = 0;
    String? firstError;
    for (var i = 0; i < sourceList.length; i++) {
      final item = sourceList[i];
      if (item is! Map<String, dynamic>) {
        failed++;
        firstError ??= '第 ${i + 1} 项不是有效的 JSON 对象';
        continue;
      }
      final validationErrors = validateSource(item);
      if (validationErrors.isNotEmpty) {
        failed++;
        firstError ??= '第 ${i + 1} 项校验失败：${validationErrors.join('；')}';
        continue;
      }
      sources.add(SourcePreview.fromRaw(item));
    }
    if (sources.isEmpty) {
      // 不再静默吞掉失败：全部失败时抛出明确错误，由调用方提示用户
      throw FormatException(
        '未解析到有效书源（失败 $failed 项）${firstError == null ? '' : '：$firstError'}',
      );
    }
    return sources;
  }

  /// 校验书源 JSON 格式
  ///
  /// 返回校验错误列表，空列表表示校验通过。
  List<String> validateSource(Map<String, dynamic> source) {
    final errors = <String>[];
    // 用 toString 宽容判空，避免第三方书源非字符串类型触发 cast 异常
    final url = source['bookSourceUrl']?.toString();
    if (url == null || url.isEmpty) {
      errors.add('缺少 bookSourceUrl');
    }
    final name = source['bookSourceName']?.toString();
    if (name == null || name.isEmpty) {
      errors.add('缺少 bookSourceName');
    }
    return errors;
  }
}
