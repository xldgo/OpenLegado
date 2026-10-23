import '../../domain/contracts/content_search_service.dart';

/// Mock装配显式注入命中夹具，不复制Rust正则算法。— Codex + Bridge
final class MockContentSearchService implements ContentSearchService {
  const MockContentSearchService();
  @override
  Future<ContentSearchMatcher?> open(
    String query, {
    required bool useRegex,
  }) async => throw UnsupportedError('离线模式未提供正文搜索夹具');
}
