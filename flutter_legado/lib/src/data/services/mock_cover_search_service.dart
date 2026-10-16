import '../../domain/contracts/cover_search_service.dart';
import '../../models/cover_candidate.dart';

/// 保留原Mock确定性封面样例，不执行网络查询。— Codex + Bridge
final class MockCoverSearchService implements CoverSearchService {
  const MockCoverSearchService();
  @override
  Future<List<CoverCandidate>> searchCover(String bookName) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final base = bookName.hashCode.abs();
    return List.generate(
      5,
      (i) => CoverCandidate(
        url: 'https://picsum.photos/seed/${base + i}/240/320',
        width: 240,
        height: 320,
      ),
    );
  }

  @override
  Future<List<String>> searchCoverRules(String name) async {
    final encoded = Uri.encodeComponent(name);
    return [
      'https://mock.cover.example/$encoded/cover_1.jpg',
      'https://mock.cover.example/$encoded/cover_2.jpg',
    ];
  }
}
