import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/cover_search_service.dart';
import '../../models/cover_candidate.dart';

/// 封面候选直接映射，不改变顺序、去重或尺寸默认值。— Codex + Bridge
final class RustCoverSearchService implements CoverSearchService {
  const RustCoverSearchService();
  @override
  Future<List<CoverCandidate>> searchCover(String bookName) async =>
      (await bridge.searchCover(bookName: bookName))
          .map(
            (v) => CoverCandidate(url: v.url, width: v.width, height: v.height),
          )
          .toList();
  @override
  Future<List<String>> searchCoverRules(String name) async =>
      bridge.searchCoverRules(name: name);
}
