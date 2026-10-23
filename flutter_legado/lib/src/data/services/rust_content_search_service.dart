import '../../bridge/content_search_bridge.dart' as bridge;
import '../../domain/contracts/content_search_service.dart';
import '../bridge/rust_errors.dart';

/// 查询只持原生编译模式；不另存Dart正则或历史正文。— Codex + Bridge
final class RustContentSearchService implements ContentSearchService {
  const RustContentSearchService();
  @override
  Future<ContentSearchMatcher?> open(
    String query, {
    required bool useRegex,
  }) async {
    final handle = await rustFuture(
      () => bridge.contentSearchBegin(query: query, useRegex: useRegex),
      operation: 'contentSearchBegin',
    );
    return handle == null ? null : _Matcher(handle);
  }
}

final class _Matcher implements ContentSearchMatcher {
  _Matcher(this.handle);
  final bridge.ContentSearchMatcher handle;
  @override
  Future<List<ContentSearchHit>> search(String content) => rustFuture(
    () async => [
      for (final hit in await handle.search(content: content))
        ContentSearchHit(
          sourceStart: hit.sourceStart.toInt(),
          sourceEnd: hit.sourceEnd.toInt(),
          snippet: hit.snippet,
          highlightStart: hit.highlightStart.toInt(),
          highlightEnd: hit.highlightEnd.toInt(),
        ),
    ],
    operation: 'contentSearchMatch',
  );
  @override
  void close() => rustCall(handle.dispose, operation: 'contentSearchDispose');
}
