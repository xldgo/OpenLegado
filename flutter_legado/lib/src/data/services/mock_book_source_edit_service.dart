import 'dart:convert';

import '../../domain/contracts/book_source_edit_service.dart';
import '../../domain/models/source_syntax_result.dart';
import '../../models/book_source.dart';

/// 保留既有简化cURL与无QuickJS占位，不声称完整规则执行。— Codex + Bridge
class MockBookSourceEditService implements BookSourceEditService {
  const MockBookSourceEditService();
  @override
  Future<bool> looksLikeCurl(String text) async {
    await Future.delayed(const Duration(milliseconds: 10));
    final t = text.trimLeft().toLowerCase();
    return t == 'curl' ||
        t.startsWith('curl ') ||
        t.startsWith('curl.exe') ||
        t.startsWith('curl\t');
  }

  @override
  Future<String> curlToAnalyzeUrl(String text) async {
    await Future.delayed(const Duration(milliseconds: 10));
    final trimmed = text.trim();
    if (trimmed.isEmpty) throw Exception('[CURL_EMPTY_INPUT]');
    // Mock：仅支持最简 `curl <url>` / `curl -L <url>`
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.isEmpty || !parts.first.toLowerCase().startsWith('curl')) {
      throw Exception('[CURL_INVALID]');
    }
    String? url;
    var follow = false;
    for (final p in parts.skip(1)) {
      if (p == '-L' || p == '--location') {
        follow = true;
        continue;
      }
      if (p.startsWith('-')) continue;
      url = p.replaceAll("'", '').replaceAll('"', '');
      break;
    }
    if (url == null || url.isEmpty) throw Exception('[CURL_MISSING_URL]');
    if (follow) return url;
    return '$url,{"followRedirects":false}';
  }

  @override
  Future<String> analyzeUrlToCurl(String text) async {
    await Future.delayed(const Duration(milliseconds: 10));
    final trimmed = text.trim();
    if (trimmed.isEmpty) throw Exception('[CURL_EMPTY_INPUT]');
    final comma = RegExp(r'\s*,\s*\{').firstMatch(trimmed);
    final url = (comma == null ? trimmed : trimmed.substring(0, comma.start))
        .trim();
    if (url.isEmpty) throw Exception('[CURL_MISSING_URL]');
    var follow = true;
    if (comma != null) {
      final opt = trimmed.substring(comma.start);
      if (opt.contains('"followRedirects":false')) follow = false;
    }
    final quoted = url.contains('?') || url.contains(' ') ? "'$url'" : url;
    return follow ? 'curl -g -L $quoted' : 'curl -g $quoted';
  }

  @override
  Future<BookSource> extractJsSource(String content) async => BookSource(
    bookSourceUrl: 'mock://js-source',
    bookSourceName: 'Mock JS 书源',
    mainJs: content,
  );
  @override
  Future<SourceSyntaxResult> checkJsSourceSyntax(String content) async =>
      SourceSyntaxResult(
        valid: content.trim().isNotEmpty,
        message: content.trim().isNotEmpty ? 'Mock 语法检查通过' : 'JS源内容为空',
      );

  /// Mock预览只消费常规类型化夹具，不调用FFI或复制Rust宽容转换算法。
  Future<List<Map<String, dynamic>>> previewFields(String json) async {
    final decoded = jsonDecode(json);
    final values = switch (decoded) {
      List<dynamic>() => decoded,
      Map<String, dynamic>() => [decoded],
      _ => throw const FormatException('书源 JSON 期望数组或对象'),
    };
    final fields = <Map<String, dynamic>>[];
    for (var i = 0; i < values.length; i++) {
      try {
        final source = await parseSource(jsonEncode(values[i]));
        fields.add({
          'bookSourceUrl': source.bookSourceUrl,
          'bookSourceName': source.bookSourceName,
          'bookSourceComment': source.bookSourceComment,
          'lastUpdateTime': source.lastUpdateTime,
        });
      } catch (error) {
        fields.add({'error': '第 ${i + 1} 项: $error'});
      }
    }
    return fields;
  }

  /// 只读解析（契约 SOURCE-PARSE-FFI-20261022）的 Mock 实现。
  ///
  /// Mock 无法调用 Rust 统一解析，这里仅做最小类型化：语法错误抛
  /// [FormatException]，非对象抛 [FormatException]，字段缺失保持默认值。
  /// 生产路径必须走 `RustBookSourceEditService.parseSource`。
  @override
  Future<BookSource> parseSource(String json) async {
    final dynamic decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException catch (e) {
      throw FormatException('书源 JSON 语法错误：${e.message}');
    }
    final Map<String, dynamic> map;
    if (decoded is List) {
      if (decoded.isEmpty) throw const FormatException('书源 JSON 数组为空');
      final first = decoded.first;
      if (first is! Map<String, dynamic>) {
        throw const FormatException('书源条目必须是 JSON 对象');
      }
      map = first;
    } else if (decoded is Map<String, dynamic>) {
      map = decoded;
    } else {
      throw const FormatException('书源 JSON 期望数组或对象');
    }
    return BookSource.fromJson(map);
  }
}
