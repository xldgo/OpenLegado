import '../../domain/models/search_batch.dart';
import '../../models/models.dart';

/// 保留原批次缺省、书籍过滤与已读标记语义。— Codex + Bridge
SearchBatch decodeSearchBatch(Map<String, dynamic> batch) => SearchBatch(
  sourceIndex: (batch['source_index'] as int?) ?? 0,
  sourceUrl: (batch['source_url'] as String?) ?? '',
  sourceName: (batch['source_name'] as String?) ?? '未知书源',
  books: (batch['books'] as List<dynamic>? ?? const [])
      .whereType<Map<String, dynamic>>()
      .map(
        (entry) => SearchResult.fromSearchBook(
          SearchBook.fromJson(entry),
          hasReadRecord: entry['hasReadRecord'] == true,
        ),
      ),
  error: batch['error'] as String?,
  finishedCount: (batch['finished_count'] as int?) ?? 0,
  totalCount: (batch['total_count'] as int?) ?? 0,
  isLast: (batch['is_last'] as bool?) ?? false,
  hasMore: batch['has_more'] as bool?,
);
