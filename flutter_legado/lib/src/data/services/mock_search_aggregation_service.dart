import '../../domain/contracts/search_aggregation_service.dart';
import '../../models/search_result.dart';

/// 离线端明确不具备原生聚合；测试或演示应注入固定结果夹具。— Codex + Bridge
final class MockSearchAggregationService implements SearchAggregationService {
  const MockSearchAggregationService();
  @override
  SearchAggregationSession open(String keyword) => _Session();
}

final class _Session implements SearchAggregationSession {
  @override
  Future<void> addAll(List<SearchResult> books) async =>
      throw UnsupportedError('离线模式未提供搜索聚合夹具');
  @override
  Future<List<SearchResult>> snapshot({bool keepOther = true}) async =>
      throw UnsupportedError('离线模式未提供搜索聚合夹具');
  @override
  Future<void> close() async {}
}
