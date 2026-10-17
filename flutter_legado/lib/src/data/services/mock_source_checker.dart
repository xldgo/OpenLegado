import '../../domain/contracts/source_checker.dart';
import '../../models/book_source.dart';
import '../repositories/mock_book_source_repository.dart';

/// 沿用原 Mock 校验，查询 Repository 与默认种子的同一份源存储。— Codex + Bridge
final class MockSourceChecker implements SourceChecker {
  MockSourceChecker({required this._store});
  final MockBookSourceStore _store;
  List<BookSource> get _sources => _store.sources;

  // ========== 书源校验（Task #87） ==========

  /// 构造 Mock 的 CheckResult（四步全部通过，无验证码/重定向）
  Map<String, dynamic> _mockCheckResult(String sourceUrl) => {
    'source_url': sourceUrl,
    'search_ok': true,
    'toc_ok': true,
    'content_ok': true,
    'search_error': null,
    'toc_error': null,
    'content_error': null,
    'total_time_ms': 321,
    'captcha': {
      'detected': false,
      'captcha_type': null,
      'matched_keyword': null,
    },
    'redirect': null,
  };

  @override
  Future<Map<String, dynamic>> checkSource(
    BookSource source, {
    String? configJson,
  }) async {
    // Mock 占位：模拟校验耗时后返回全部通过
    await Future.delayed(const Duration(milliseconds: 300));
    return _mockCheckResult(source.bookSourceUrl);
  }

  @override
  Stream<Map<String, dynamic>> checkSourcesStream(
    List<String> sourceUrls, {
    String? configJson,
  }) async* {
    // Mock 占位：逐个推送全部通过的进度（空列表校验全部 mock 书源）
    final urls = sourceUrls.isEmpty
        ? _sources.map((s) => s.bookSourceUrl).toList()
        : sourceUrls;
    final total = urls.length;
    for (var i = 0; i < total; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      final matches = _sources
          .where((s) => s.bookSourceUrl == urls[i])
          .toList();
      final name = matches.isEmpty ? urls[i] : matches.first.bookSourceName;
      yield {
        'index': i,
        'total': total,
        'is_last': i == total - 1,
        'source_name': name,
        'result': _mockCheckResult(urls[i]),
      };
    }
  }

  @override
  Future<void> cancelCheckSources() async {
    // Mock 占位：无后台任务，无需取消
  }
}
