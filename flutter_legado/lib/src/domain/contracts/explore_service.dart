import '../../models/models.dart';
import '../models/explore_action_result.dart';

/// 发现解析与脚本求值，不持有页面分页状态。— Codex + Bridge
abstract interface class ExploreService {
  Future<List<ExploreCategory>> parseCategories(
    String exploreUrl, {
    BookSource? source,
  });
  Future<List<SearchBook>> fetchBooks(BookSource source, String url, int page);
  Future<ExploreActionResult> evaluateAction({
    required BookSource source,
    required String actionJs,
  });
  Future<String> evaluateUiJs({
    required BookSource source,
    required String jsStr,
  });
}
