import '../../models/search_result.dart';

/// 查询级聚合能力；网络执行仍由SearchService/SearchSession拥有。— Codex + Bridge
abstract interface class SearchAggregationService {
  SearchAggregationSession open(String keyword);
}

abstract interface class SearchAggregationSession {
  Future<void> addAll(List<SearchResult> books);
  Future<List<SearchResult>> snapshot({bool keepOther = true});
  Future<void> close();
}
