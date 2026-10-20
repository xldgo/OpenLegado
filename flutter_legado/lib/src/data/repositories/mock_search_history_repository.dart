import '../../domain/contracts/search_history_repository.dart';
import '../../models/models.dart';

/// 共享的唯一搜索历史存储，保留原读写语义。— Codex + Bridge
final class MockSearchHistoryRepository implements SearchHistoryRepository {
  final List<SearchKeyword> _searchHistory = [];

  // ========== 搜索历史 ==========

  @override
  Future<List<SearchKeyword>> getSearchHistory({int limit = 50}) async =>
      _searchHistory.take(limit).toList();

  @override
  Future<List<String>> searchHistoryByPrefix(
    String prefix, {
    int limit = 20,
  }) async {
    return _searchHistory
        .where((k) => k.word.startsWith(prefix))
        .take(limit)
        .map((k) => k.word)
        .toList();
  }

  @override
  Future<void> addSearchKeyword(String keyword, String bookName) async {
    _searchHistory.insert(0, SearchKeyword(word: keyword));
  }

  @override
  Future<void> deleteSearchKeyword(String keyword) async {
    _searchHistory.removeWhere((k) => k.word == keyword);
  }

  @override
  Future<void> clearSearchHistory() async {
    _searchHistory.clear();
  }
}
