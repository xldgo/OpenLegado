import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/rss_article_repository.dart';
import '../../models/models.dart';
import 'rss_json_decode.dart';

/// 直接复用既有FRB，不持有页面状态。— Codex + Bridge
final class RustRssArticleRepository implements RssArticleRepository {
  const RustRssArticleRepository();

  /// 获取 RSS 文章列表
  @override
  Future<List<RssFeedArticle>> getRssArticles(String sourceUrl) async {
    final json = await bridge.rssFetchArticles(sourceUrl: sourceUrl);
    return decodeRssList(json, 'getRssArticles', (m) {
      return RssFeedArticle(
        title: m['title'] as String? ?? '',
        url: m['link'] as String? ?? m['url'] as String? ?? '',
        description: m['description'] as String?,
        pubDate: m['pubDate'] as String?,
        imageUrl: m['image'] as String? ?? m['imageUrl'] as String?,
        content: m['content'] as String?,
      );
    });
  }

  /// 清空指定 RSS 源本地文章缓存
  @override
  Future<void> rssClearArticles(String sourceUrl) =>
      bridge.rssClearArticles(sourceUrl: sourceUrl);
}
