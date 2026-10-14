import '../../models/models.dart';

/// 单源搜索批次；结果与元信息已由数据适配器解码。— Codex + Bridge
final class SearchBatch {
  SearchBatch({
    this.sourceIndex = 0,
    this.sourceUrl = '',
    this.sourceName = '未知书源',
    Iterable<SearchResult> books = const [],
    this.error,
    this.finishedCount = 0,
    this.totalCount = 0,
    this.isLast = false,
    this.hasMore,
  }) : books = List.unmodifiable(books);

  final int sourceIndex;
  final String sourceUrl;
  final String sourceName;
  final List<SearchResult> books;
  final String? error;
  final int finishedCount;
  final int totalCount;
  final bool isLast;

  /// 未提供时保留当前分页状态，不能当成 false。
  final bool? hasMore;
}
