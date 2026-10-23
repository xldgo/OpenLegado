import '../../bridge/content_search_bridge.dart' as bridge;
import '../../domain/contracts/content_search_service.dart';
import '../bridge/rust_errors.dart';
import '../bridge/managed_rust_stream.dart';

/// 每个订阅持有独立取消凭据；正文和匹配状态不经Dart往返。— Codex + Bridge
final class RustContentSearchService implements ContentSearchService {
  const RustContentSearchService();
  @override
  Stream<ContentSearchBatch> search({
    required String bookUrl,
    required String query,
    required bool useRegex,
    required bool useReplace,
    required ContentSearchScope scope,
    required int currentChapterIndex,
  }) =>
      managedRustStream(
        (request) => rustStream(
          () => bridge.contentSearch(
            options: bridge.ContentSearchOptionsDto(
              bookUrl: bookUrl,
              query: query,
              useRegex: useRegex,
              useReplace: useReplace,
              currentChapterIndex: currentChapterIndex,
              scope: switch (scope) {
                ContentSearchScope.current =>
                  bridge.ContentSearchScopeDto.current,
                ContentSearchScope.cached =>
                  bridge.ContentSearchScopeDto.cached,
                ContentSearchScope.network =>
                  bridge.ContentSearchScopeDto.network,
              },
            ),
            request: request,
          ),
          operation: 'contentSearch',
        ),
      ).map(
        (batch) => ContentSearchBatch(
          chapterIndex: batch.chapterIndex,
          chapterTitle: batch.chapterTitle,
          scanned: batch.scanned.toInt(),
          total: batch.total.toInt(),
          error: batch.error,
          limitReached: batch.limitReached,
          hits: [
            for (final hit in batch.hits)
              ContentSearchHit(
                sourceStart: hit.sourceStart.toInt(),
                sourceEnd: hit.sourceEnd.toInt(),
                snippet: hit.snippet,
                highlightStart: hit.highlightStart.toInt(),
                highlightEnd: hit.highlightEnd.toInt(),
              ),
          ],
        ),
      );
}
