import '../bridge/rust_errors.dart';
import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/rss_article_repository.dart';
import '../../models/models.dart';
import '../bridge/business_dto_mapping.dart';

/// 直接复用既有FRB，不持有页面状态。— Codex + Bridge
final class RustRssArticleRepository implements RssArticleRepository {
  const RustRssArticleRepository();

  /// 获取 RSS 文章列表
  @override
  Future<List<RssFeedArticle>> getRssArticles(String sourceUrl) async {
    return (await rustFuture(
      () => bridge.rssFetchArticles(sourceUrl: sourceUrl),
      operation: 'rssFetchArticles',
    )).map(rssArticleFromDto).toList();
  }

  /// 清空指定 RSS 源本地文章缓存
  @override
  Future<void> rssClearArticles(String sourceUrl) => rustFuture(
    () => bridge.rssClearArticles(sourceUrl: sourceUrl),
    operation: 'rssClearArticles',
  );
}
