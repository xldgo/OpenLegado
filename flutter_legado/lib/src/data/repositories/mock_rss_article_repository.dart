import '../../domain/contracts/rss_article_repository.dart';
import '../../models/models.dart';

/// 订阅Mock使用装配实例内的同一份数据。— Codex + Bridge
final class MockRssArticleRepository implements RssArticleRepository {
  const MockRssArticleRepository();
  @override
  Future<List<RssFeedArticle>> getRssArticles(String sourceUrl) async {
    // 每源 5 篇假文章
    return List.generate(5, (i) {
      return RssFeedArticle(
        title: '文章标题 ${i + 1} - ${sourceUrl.contains('1') ? '科技' : '文学'}',
        url: 'mock://rss/article/$sourceUrl/$i',
        description: '这是第${i + 1}篇文章的摘要描述。',
        pubDate: DateTime.now().subtract(Duration(days: i)).toIso8601String(),
        imageUrl: 'https://via.placeholder.com/300x150?text=Article${i + 1}',
        content: '<p>这是第${i + 1}篇文章的正文内容。</p>' * 5,
      );
    });
  }

  @override
  Future<void> rssClearArticles(String sourceUrl) async {
    // Mock：无本地文章表，空实现即可
  }
}
