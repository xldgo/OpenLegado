import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bridge/ffi/ffi.dart' as bridge;
import '../../data/bridge/rust_errors.dart';
import '../../data/services/source_import_service.dart';
import '../../data/services/mock_book_source_edit_service.dart';
import '../../domain/services/source_import_parser.dart';
import '../../platform/source_import_file_reader.dart';
import 'application_dependencies.dart';

/// 预览展示字段的 Rust 归一化实现：逐项复用与导入相同的条目解析器。
Future<List<Map<String, dynamic>>> _rustPreviewNormalize(
  String jsonArray,
) async {
  final raw = await rustFuture(
    () => bridge.sourcePreviewFields(jsonArray: jsonArray),
    operation: 'sourcePreviewFields',
  );
  final decoded = jsonDecode(raw);
  if (decoded is! List) {
    throw const FormatException('预览字段归一化返回格式错误');
  }
  return decoded.cast<Map<String, dynamic>>();
}

/// 正式与Mock在装配处选择能力，测试可以注入固定返回值而无需原生库。
final sourcePreviewNormalizerProvider = Provider<SourcePreviewNormalizer>(
  (ref) => ref.watch(mockModeProvider)
      ? const MockBookSourceEditService().previewFields
      : _rustPreviewNormalize,
);

/// 每次操作使用同一份已装配的领域依赖。— Codex + UI
final sourceImportServiceProvider = Provider<SourceImportService>(
  (ref) => SourceImportService(
    repository: ref.watch(bookSourceRepositoryProvider),
    fetchText: ref.watch(networkServiceProvider).httpGet,
    readFile: readSourceImportFile,
    applyReplaceRules: ref
        .watch(replaceRuleServiceProvider)
        .applyReplaceRulesToSource,
    normalize: ref.watch(sourcePreviewNormalizerProvider),
  ),
);
