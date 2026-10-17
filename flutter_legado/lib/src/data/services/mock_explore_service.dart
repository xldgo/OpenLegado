import '../../domain/contracts/explore_service.dart';
import '../../domain/models/explore_action_result.dart';
import '../../models/models.dart';

/// 保留Mock分类与分页样例，不在Dart复制Rust JS引擎。— Codex + Bridge
final class MockExploreService implements ExploreService {
  const MockExploreService();
  @override
  Future<List<ExploreCategory>> parseCategories(
    String exploreUrl, {
    BookSource? source,
  }) async {
    if (exploreUrl.isEmpty) return [];
    return exploreUrl.split('\n').where((l) => l.contains('::')).map((line) {
      final parts = line.split('::');
      return ExploreCategory(
        title: parts[0].trim(),
        url: parts.length > 1 ? parts[1].trim() : '',
      );
    }).toList();
  }

  @override
  Future<List<SearchBook>> fetchBooks(
    BookSource source,
    String url,
    int page,
  ) async {
    return List.generate(10, (i) {
      return SearchBook(
        bookUrl: 'mock://explore/$url/$page/$i',
        name: '发现书籍 ${(page - 1) * 10 + i + 1}',
        author: '作者${i + 1}',
        coverUrl: 'https://www.biquge.com.cn/files/article/image/${i + 1}.jpg',
        intro: '发现页书籍简介',
        origin: 'https://www.biquge.com.cn',
        originName: '笔趣阁',
        latestChapterTitle: '最新章节',
      );
    });
  }

  @override
  Future<ExploreActionResult> evaluateAction({
    required BookSource source,
    required String actionJs,
  }) async =>
      ExploreActionResult(refreshExplore: actionJs.contains('refreshExplore'));
  @override
  Future<String> evaluateUiJs({
    required BookSource source,
    required String jsStr,
  }) async => jsStr;
}
