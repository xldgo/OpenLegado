import '../../domain/contracts/content_search_service.dart';

/// Mock只注入明确搜索批次，不复制章节选择或正文匹配。— Codex + Bridge
final class MockContentSearchService implements ContentSearchService {
  const MockContentSearchService();
  @override
  Stream<ContentSearchBatch> search({
    required String bookUrl,
    required String query,
    required bool useRegex,
    required bool useReplace,
    required ContentSearchScope scope,
    required int currentChapterIndex,
  }) => Stream.error(UnsupportedError('离线模式未提供正文搜索夹具'));
}
