import '../../models/models.dart';

/// 订阅领域数据访问，界面不依赖FRB。— Codex + Bridge
abstract interface class RssArticleRepository {
  /// 获取 RSS 文章列表
  Future<List<RssFeedArticle>> getRssArticles(String sourceUrl);

  /// 清空指定 RSS 源本地文章缓存（对齐 clearArticles）
  Future<void> rssClearArticles(String sourceUrl);
}
