import 'dart:convert';

import '../../bridge/rust_lib.dart' as bridge;
import '../bridge/rust_json_decode.dart';
import '../../domain/contracts/search_service.dart';
import '../../domain/models/search_batch.dart';
import '../../models/models.dart';
import '../bridge/search_batch_decode.dart';

/// 原搜索访问实现独立迁移，不重建或初始化运行时。— Codex + Bridge
final class RustSearchService implements SearchService {
  const RustSearchService();

  // ========== 搜索操作 ==========

  /// 搜索书籍
  ///
  /// [sourceUrls] 为空则搜索所有启用的书源。
  @override
  Future<List<SearchResult>> searchBooks(
    String keyword, {
    List<String>? sourceUrls,
  }) async {
    final urlsJson = sourceUrls != null ? jsonEncode(sourceUrls) : '[]';
    final json = await bridge.searchBooks(
      keyword: keyword,
      sourceUrlsJson: urlsJson,
    );
    final list = decodeRustJsonList(json, 'bookApi');
    return list.map((e) {
      final map = e as Map<String, dynamic>;
      return SearchResult.fromSearchBook(
        SearchBook.fromJson(map),
        hasReadRecord: map['hasReadRecord'] == true,
      );
    }).toList();
  }

  /// 精确搜索（对齐原版 `WebBook.preciseSearchAwait`）
  @override
  Future<SearchBook> preciseSearch(
    String name,
    String author, {
    List<String>? sourceUrls,
  }) async {
    final urlsJson = sourceUrls != null ? jsonEncode(sourceUrls) : '[]';
    final json = await bridge.preciseSearch(
      name: name,
      author: author,
      sourceUrlsJson: urlsJson,
    );
    final map = jsonDecode(json) as Map<String, dynamic>;
    return SearchBook.fromJson(map);
  }

  /// 多源并行搜索
  @override
  Future<List<Map<String, dynamic>>> searchMulti(
    String query, {
    List<String>? sourceUrls,
  }) async {
    final urlsJson = sourceUrls != null ? jsonEncode(sourceUrls) : '[]';
    final json = await bridge.searchMulti(
      query: query,
      sourceUrlsJson: urlsJson,
    );
    final list = decodeRustJsonList(json, 'bookApi');
    return list.map((e) => e as Map<String, dynamic>).toList();
  }

  /// 多源渐进式（流式）搜索
  ///
  /// 每完成一个书源即推送一个批次 Map（字段见 [SearchBatch]）。
  /// [page] — 页码透传（批次B G-B-01：同关键词翻页递增、新关键词重置为 1）。
  @override
  Stream<SearchBatch> searchMultiStream(
    String query, {
    List<String>? sourceUrls,
    int page = 1,
  }) {
    final urlsJson = sourceUrls != null ? jsonEncode(sourceUrls) : '[]';
    return bridge
        .searchMultiStream(query: query, sourceUrlsJson: urlsJson, page: page)
        .map(
          (batch) =>
              decodeSearchBatch(decodeRustJsonMap(batch, 'searchMultiStream')),
        );
  }

  /// 取消搜索
  @override
  Future<void> cancelSearch() => bridge.searchCancel();

  /// 暂停正在进行的流式搜索（软挂起，批次B G-B-04）
  @override
  Future<void> pauseSearch() => bridge.searchPause();

  /// 恢复已暂停的流式搜索（批次B G-B-04）
  @override
  Future<void> resumeSearch() => bridge.searchResume();
}
