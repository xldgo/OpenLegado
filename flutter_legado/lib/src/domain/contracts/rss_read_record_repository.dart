import '../../models/models.dart';

/// 订阅领域数据访问，界面不依赖FRB。— Codex + Bridge
abstract interface class RssReadRecordRepository {
  /// 标记 RSS 文章为已读
  Future<void> rssMarkRead(String origin, String title, [String? link]);

  /// 判断 RSS 文章是否已读（按 link）
  Future<bool> rssIsRead(String link);

  /// 判断 RSS 文章是否已读（按 origin + title）
  Future<bool> rssIsReadByTitle(String origin, String title);

  /// 清空所有 RSS 已读记录
  Future<void> rssClearReadRecords();

  /// 获取 RSS 已读记录总数
  Future<int> rssReadRecordCount();

  /// 获取 RSS 已读记录列表（按 readTime 降序）
  Future<List<RssReadRecordRow>> rssListReadRecords([int? limit]);

  /// 按 RSS 源 origin 获取已读记录（对齐原版 getRecordsByOrigin）
  Future<List<RssReadRecordRow>> rssListReadRecordsByOrigin(
    String origin, [
    int? limit,
  ]);
}
