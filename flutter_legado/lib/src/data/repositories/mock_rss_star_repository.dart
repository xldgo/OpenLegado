import '../../domain/contracts/rss_star_repository.dart';
import '../../models/models.dart';

/// 订阅Mock使用装配实例内的同一份数据。— Codex + Bridge
final class MockRssStarRepository implements RssStarRepository {
  final List<RssStar> _rssStars = [];

  @override
  Future<List<RssStar>> getRssStars() async => List.from(_rssStars);

  @override
  Future<RssStar> addRssStar(RssStar star) async {
    _rssStars.add(star);
    return star;
  }

  @override
  Future<void> deleteRssStar(String link) async {
    _rssStars.removeWhere((s) => s.link == link);
  }

  @override
  Future<bool> isStarred(String link) async =>
      _rssStars.any((s) => s.link == link);
}
