import 'dart:convert';

import '../../utils/error_message.dart';
import '../../domain/contracts/book_source_repository.dart';
import '../../domain/models/import_result.dart';
import '../../domain/models/source_preview.dart';
import '../../domain/services/source_import_parser.dart';
import '../../domain/models/http_response.dart';

/// 文本 GET 沿用宿主的网络栈与显式超时。— Codex + Bridge
typedef SourceImportTextFetcher = Future<HttpTextResponse> Function(
  String url, {
  required Duration timeout,
});

/// 文件不存在返回 null，读取失败抛出原异常。
typedef SourceImportFileReader = Future<String?> Function(String path);

/// 书源作用域替换由宿主注入，执行失败由导入流程保留原文。
typedef SourceImportReplaceRules = Future<String> Function(
  String json,
  String name,
  String url,
);

/// 编排预览与逐条导入，只依赖明确注入的数据能力。— Codex + Bridge
class SourceImportService {
  SourceImportService({
    required this._repository,
    required this._fetchText,
    required this._readFile,
    required this._applyReplaceRules,
    this._parser = const SourceImportParser(),
  });

  final BookSourceRepository _repository;
  final SourceImportTextFetcher _fetchText;
  final SourceImportFileReader _readFile;
  final SourceImportReplaceRules _applyReplaceRules;
  final SourceImportParser _parser;

  /// 从 URL 拉取并解析书源列表（仅预览，不写入数据库）
  ///
  /// 对标原版 ImportBookSourceViewModel.importSourceUrl + comparisonSource：
  /// 先拉取解析出全部候选书源，由 UI 层展示确认页供用户选择后再导入。
  Future<List<SourcePreview>> fetchSourcesFromUrl(String url) async {
    final response = await _fetchText(
      url,
      timeout: const Duration(seconds: 30),
    );
    if (!response.isSuccess) {
      throw FormatException('HTTP 请求失败：状态码 ${response.statusCode}');
    }
    return _parser.parseSourcesText(response.body);
  }

  /// 从本地文件拉取并解析书源列表（仅预览，不写入数据库）
  Future<List<SourcePreview>> fetchSourcesFromFile(String filePath) async {
    final content = await _readFile(filePath);
    if (content == null) {
      throw FormatException('文件不存在：$filePath');
    }
    return _parser.parseSourcesText(content);
  }

  /// 从 JSON 字符串导入书源
  ///
  /// 支持单个书源对象或书源数组。[unit] 用于结果汇总文案（默认「书源」）。
  Future<ImportResult> importFromJson(
    String jsonStr, {
    String unit = '书源',
  }) async {
    final errors = <String>[];
    var total = 0;
    var success = 0;
    var failed = 0;
    var skipped = 0;

    try {
      final sourceList = _parser.decodeSources(jsonStr);
      if (sourceList == null) {
        return ImportResult(
          total: 0,
          success: 0,
          failed: 0,
          skipped: 0,
          errors: ['无效的 JSON 格式：期望数组或对象'],
          unit: unit,
        );
      }

      total = sourceList.length;

      for (var i = 0; i < sourceList.length; i++) {
        final item = sourceList[i];
        if (item is! Map<String, dynamic>) {
          failed++;
          errors.add('第 ${i + 1} 项不是有效的 JSON 对象');
          continue;
        }

        final validationErrors = _parser.validateSource(item);
        if (validationErrors.isNotEmpty) {
          skipped++;
          errors.add('第 ${i + 1} 项校验失败：${validationErrors.join('；')}');
          continue;
        }

        try {
          final json = jsonEncode(item);
          // [书源作用域 | 2026-09-13] 导入时先应用「书源作用域」替换规则：
          // 按源名称/源 URL 匹配 scope 后对整源 JSON 应用替换；
          // 应用失败保持原文，绝不中断导入（对齐原版语义）
          final applied = await _applySourceReplaceRules(
            json,
            (item['bookSourceName'] as String?) ?? '',
            (item['bookSourceUrl'] as String?) ?? '',
          );
          await _repository.importBookSources('[$applied]');
          success++;
        } catch (e) {
          failed++;
          final name = item['bookSourceName'] ?? '未知书源';
          // 领域错误保留来源失败消息，不显示桥接类型。
          final msg = errorMessage(e);
          errors.add('导入「$name」失败：$msg');
        }
      }
    } on FormatException catch (e) {
      return ImportResult(
        total: 0,
        success: 0,
        failed: 0,
        skipped: 0,
        errors: ['JSON 解析错误：${e.message}'],
        unit: unit,
      );
    }

    return ImportResult(
      total: total,
      success: success,
      failed: failed,
      skipped: skipped,
      errors: errors,
      unit: unit,
    );
  }

  /// 从 URL 导入书源
  Future<ImportResult> importFromUrl(String url, {String unit = '书源'}) async {
    try {
      final response = await _fetchText(
        url,
        timeout: const Duration(seconds: 30),
      );

      if (!response.isSuccess) {
        return ImportResult(
          total: 0,
          success: 0,
          failed: 0,
          skipped: 0,
          errors: ['HTTP 请求失败：状态码 ${response.statusCode}'],
          unit: unit,
        );
      }

      return await importFromJson(response.body, unit: unit);
    } catch (e) {
      return ImportResult(
        total: 0,
        success: 0,
        failed: 0,
        skipped: 0,
        errors: ['从 URL 导入失败：$e'],
        unit: unit,
      );
    }
  }

  /// 从文件导入书源
  Future<ImportResult> importFromFile(
    String filePath, {
    String unit = '书源',
  }) async {
    try {
      final content = await _readFile(filePath);
      if (content == null) {
        return ImportResult(
          total: 0,
          success: 0,
          failed: 0,
          skipped: 0,
          errors: ['文件不存在：$filePath'],
          unit: unit,
        );
      }

      return await importFromJson(content, unit: unit);
    } catch (e) {
      return ImportResult(
        total: 0,
        success: 0,
        failed: 0,
        skipped: 0,
        errors: ['读取文件失败：$e'],
        unit: unit,
      );
    }
  }

  /// [书源作用域 | 2026-09-13] 导入前对整源 JSON 应用「书源作用域」替换规则
  ///
  /// 契约 §2.8 `applyReplaceRulesToSource`：`isEnabled && scopeSource &&
  /// pattern 非空` 且 scope/excludeScope 按源名称/源 URL（忽略大小写）
  /// 匹配的规则生效；未命中返回原文。
  /// 本方法对「调用本身抛异常」（如 FFI 未就绪/环境不支持）做兜底：
  /// 保持原文并继续导入，绝不因替换失败中断导入流程。
  Future<String> _applySourceReplaceRules(
    String sourceJson,
    String sourceName,
    String sourceUrl,
  ) async {
    try {
      return await _applyReplaceRules(sourceJson, sourceName, sourceUrl);
    } catch (_) {
      // 替换失败保持原文（对齐原版语义：不中断导入）
      return sourceJson;
    }
  }
}
