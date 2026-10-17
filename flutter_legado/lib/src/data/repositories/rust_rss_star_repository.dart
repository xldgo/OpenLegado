import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/rss_star_repository.dart';
import '../../models/models.dart';
import '../bridge/business_dto_mapping.dart';

/// 直接复用既有FRB，不持有页面状态。— Codex + Bridge
final class RustRssStarRepository implements RssStarRepository {
  const RustRssStarRepository();

  /// 获取所有 RSS 收藏
  @override
  Future<List<RssStar>> getRssStars() async {
    return (await bridge.rssStarList()).map(rssStarFromDto).toList();
  }

  /// 添加 RSS 收藏
  @override
  Future<RssStar> addRssStar(RssStar star) async {
    await bridge.rssStarAdd(
      sourceUrl: star.origin,
      title: star.title,
      link: star.link,
    );
    return star;
  }

  /// 删除 RSS 收藏
  @override
  Future<void> deleteRssStar(String link) async {
    await bridge.rssStarDelete(link: link);
  }

  /// 判断是否已收藏
  @override
  Future<bool> isStarred(String link) => bridge.rssStarIsStarred(link: link);
}
