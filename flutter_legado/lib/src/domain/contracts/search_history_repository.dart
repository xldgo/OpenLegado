import '../../models/models.dart';

/// 搜索页与书内搜索共享的历史存储，不持有展示状态。— Codex + Bridge
abstract interface class SearchHistoryRepository {
  Future<List<SearchKeyword>> getSearchHistory({int limit = 50});
  Future<List<String>> searchHistoryByPrefix(String prefix, {int limit = 20});
  Future<void> addSearchKeyword(String keyword, String bookName);
  Future<void> deleteSearchKeyword(String keyword);
  Future<void> clearSearchHistory();
}
