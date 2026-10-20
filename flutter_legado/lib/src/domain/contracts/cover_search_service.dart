import '../../models/cover_candidate.dart';

/// 封面候选查询，不持有页面状态。— Codex + Bridge
abstract interface class CoverSearchService {
  Future<List<CoverCandidate>> searchCover(String bookName);
  Future<List<String>> searchCoverRules(String name);
}
