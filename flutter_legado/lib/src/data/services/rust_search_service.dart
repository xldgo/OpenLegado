import '../bridge/rust_errors.dart';
import '../../bridge/rust_lib.dart' as bridge;
import '../../domain/contracts/search_service.dart';
import '../../domain/models/search_batch.dart';
import '../../models/models.dart';
import '../bridge/stream_dto_mapping.dart';
import '../bridge/managed_rust_stream.dart';

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
    final books = await rustFuture(
      () => bridge.searchBooks(keyword: keyword, sourceUrls: sourceUrls ?? []),
      operation: 'searchBooks',
    );
    return books
        .map(
          (value) => SearchResult.fromSearchBook(
            searchBookFromDto(value),
            hasReadRecord: value.hasReadRecord,
          ),
        )
        .toList();
  }

  /// 精确搜索（对齐原版 `WebBook.preciseSearchAwait`）
  @override
  Future<SearchBook> preciseSearch(
    String name,
    String author, {
    List<String>? sourceUrls,
  }) async {
    return searchBookFromDto(
      await rustFuture(
        () => bridge.preciseSearch(
          name: name,
          author: author,
          sourceUrls: sourceUrls ?? [],
        ),
        operation: 'preciseSearch',
      ),
    );
  }

  /// 多源并行搜索
  @override
  Future<List<Map<String, dynamic>>> searchMulti(
    String query, {
    List<String>? sourceUrls,
  }) async {
    return (await rustFuture(
          () => bridge.searchMulti(query: query, sourceUrls: sourceUrls ?? []),
          operation: 'searchMulti',
        ))
        .map(
          (v) => <String, dynamic>{
            'book_name': v.bookName,
            'author': v.author,
            'cover_url': v.coverUrl,
            'intro': v.intro,
            'latest_chapter': v.latestChapter,
            'source_url': v.sourceUrl,
            'source_name': v.sourceName,
            'book_url': v.bookUrl,
            'relevance_score': v.relevanceScore,
            'originOrder': v.originOrder,
            'hasReadRecord': v.hasReadRecord,
            if (v.readRecordAuthor != null)
              'readRecordAuthor': v.readRecordAuthor,
            if (v.variable != null) 'variable': v.variable,
          },
        )
        .toList();
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
    return managedRustStream(
      (request) => rustStream(
        () => bridge.searchMultiStream(
          query: query,
          sourceUrls: sourceUrls ?? [],
          page: page,
          request: request,
        ),
        operation: 'searchMultiStream',
      ),
    ).map(searchBatchFromDto);
  }

  /// 取消搜索
  @override
  Future<void> cancelSearch() =>
      rustFuture(() => bridge.searchCancel(), operation: 'searchCancel');

  /// 暂停正在进行的流式搜索（软挂起，批次B G-B-04）
  @override
  Future<void> pauseSearch() =>
      rustFuture(() => bridge.searchPause(), operation: 'searchPause');

  /// 恢复已暂停的流式搜索（批次B G-B-04）
  @override
  Future<void> resumeSearch() =>
      rustFuture(() => bridge.searchResume(), operation: 'searchResume');
}
