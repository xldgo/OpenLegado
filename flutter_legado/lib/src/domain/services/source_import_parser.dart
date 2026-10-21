import 'dart:convert';

import '../models/source_preview.dart';

/// 预览展示字段由 Rust 归一化产出（契约 SOURCE-PARSE-FFI-20261022）。
///
/// 入参为原始 JSON 文本，出参为与输入同序的展示字段数组，每项包含
/// `bookSourceUrl` / `bookSourceName` / `bookSourceComment` / `lastUpdateTime`。
/// 生产实现直连 Rust `sourcePreviewFields`；此处以 typedef 注入，便于测试替换。
typedef SourcePreviewNormalizer =
    Future<List<Map<String, dynamic>>> Function(String json);

/// 书源预览解析：原始 Map 保留原文，展示字段取自 Rust 归一化结果。
/// 不再自带任何归一化规则（此前 `?.toString()` / 本地整数解析会与导入分叉）。
class SourceImportParser {
  const SourceImportParser({this.normalize});

  /// Rust 归一化入口；为空时视为不支持（调用方须注入）
  final SourcePreviewNormalizer? normalize;

  /// 保留原始条目类型；非法 JSON 抛异常，非对象/数组返回 null。
  List<dynamic>? decodeSources(String text) {
    final decoded = jsonDecode(text);
    if (decoded is List) return decoded;
    if (decoded is Map<String, dynamic>) return [decoded];
    return null;
  }

  /// 解析书源 JSON 文本为预览条目列表（仅预览，不写入数据库）
  ///
  /// 支持单个书源对象或书源数组。[raw] 保留原文供确认导入直传；
  /// 展示字段由 [normalize]（Rust）产出，与最终入库同一套字段解释。
  Future<List<SourcePreview>> parseSourcesText(String jsonStr) async {
    final trimmed = jsonStr.trim();
    final normalizer = normalize;
    if (normalizer == null) {
      throw const FormatException('未注入书源归一化入口');
    }
    // 原件（数组/单对象）用于取 raw；归一化由 Rust 完成并按同序返回
    final sourceList = decodeSources(trimmed) ?? <dynamic>[];
    final normalized = await normalizer(trimmed);
    if (normalized.length != sourceList.length) {
      throw FormatException(
        '预览归一化条目数不一致：原文 ${sourceList.length} 条、归一化 ${normalized.length} 条',
      );
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
      // 必填校验基于 Rust 归一化字段，保证与确认导入阶段的跳过规则一致
      final validationErrors = validateSource(normalized[i]);
      if (validationErrors.isNotEmpty) {
        failed++;
        firstError ??= '第 ${i + 1} 项校验失败：${validationErrors.join('；')}';
        continue;
      }
      sources.add(SourcePreview.fromNormalized(item, normalized[i]));
    }
    if (sources.isEmpty) {
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
