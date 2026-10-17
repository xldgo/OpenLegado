import '../../bridge/rust_lib.dart' as bridge;
import '../bridge/business_dto_mapping.dart';
import '../../domain/contracts/search_history_repository.dart';
import '../../models/models.dart';

/// 共享的唯一搜索历史存储，保留原读写语义。— Codex + Bridge
final class RustSearchHistoryRepository implements SearchHistoryRepository {
  const RustSearchHistoryRepository();

  // ========== 搜索历史 ==========

  /// 获取搜索历史
  @override
  Future<List<SearchKeyword>> getSearchHistory({int limit = 50}) async {
    return (await bridge.searchHistoryList(limit: businessI32(limit)))
        .map(searchHistoryFromDto)
        .toList();
  }

  /// 按前缀搜索历史关键词（用于搜索联想）
  @override
  Future<List<String>> searchHistoryByPrefix(
    String prefix, {
    int limit = 20,
  }) async {
    return bridge.searchHistoryByPrefix(
      prefix: prefix,
      limit: businessI32(limit),
    );
  }

  /// 添加搜索关键词
  @override
  Future<void> addSearchKeyword(String keyword, String bookName) async {
    await bridge.searchHistoryAdd(keyword: keyword, bookName: bookName);
  }

  /// 删除搜索关键词
  @override
  Future<void> deleteSearchKeyword(String keyword) async {
    await bridge.searchHistoryDelete(keyword: keyword);
  }

  /// 清空搜索历史
  @override
  Future<void> clearSearchHistory() async {
    await bridge.searchHistoryClear();
  }
}
