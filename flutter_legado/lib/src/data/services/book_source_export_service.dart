import 'dart:convert';

import '../../domain/contracts/book_source_repository.dart';

/// 书源导出格式与筛选规则沿用原实现。— Codex + Bridge
class BookSourceExportService {
  const BookSourceExportService(this._repository);
  final BookSourceRepository _repository;

  /// 导出选中书源为 JSON
  ///
  /// [sourceUrls] 要导出的书源 URL 列表。
  /// 返回格式化的 JSON 字符串。
  Future<String> exportSelectedSources(List<String> sourceUrls) async {
    final allSources = await _repository.getBookSources();
    final selected = allSources
        .where((s) => sourceUrls.contains(s.bookSourceUrl))
        .toList();

    if (selected.isEmpty) {
      return '[]';
    }

    final jsonList = selected.map((s) => s.toJson()).toList();
    return const JsonEncoder.withIndent('  ').convert(jsonList);
  }

  /// 导出全部书源为格式化 JSON
  Future<String> exportAllSourcesFormatted() async {
    final allSources = await _repository.getBookSources();
    final jsonList = allSources.map((s) => s.toJson()).toList();
    return const JsonEncoder.withIndent('  ').convert(jsonList);
  }
}
