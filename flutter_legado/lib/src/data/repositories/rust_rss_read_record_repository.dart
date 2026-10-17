import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/rss_read_record_repository.dart';
import '../../models/models.dart';
import '../bridge/business_dto_mapping.dart';

/// 直接复用既有FRB，不持有页面状态。— Codex + Bridge
final class RustRssReadRecordRepository implements RssReadRecordRepository {
  const RustRssReadRecordRepository();

  /// 标记 RSS 文章为已读
  @override
  Future<void> rssMarkRead(String origin, String title, [String? link]) =>
      bridge.rssMarkRead(origin: origin, title: title, link: link);

  /// 判断 RSS 文章是否已读（按 link）
  @override
  Future<bool> rssIsRead(String link) => bridge.rssIsRead(link: link);

  /// 判断 RSS 文章是否已读（按 origin + title）
  @override
  Future<bool> rssIsReadByTitle(String origin, String title) =>
      bridge.rssIsReadByTitle(origin: origin, title: title);

  /// 清空所有 RSS 已读记录
  @override
  Future<void> rssClearReadRecords() => bridge.rssClearReadRecords();

  /// 获取 RSS 已读记录总数
  @override
  Future<int> rssReadRecordCount() async =>
      (await bridge.rssReadRecordCount()).toInt();

  /// 获取 RSS 已读记录列表（按 readTime 降序）
  @override
  Future<List<RssReadRecordRow>> rssListReadRecords([int? limit]) async {
    return (await bridge.rssListReadRecords(
      limit: limit == null ? null : businessI32(limit),
    )).map(rssReadFromDto).toList();
  }

  @override
  Future<List<RssReadRecordRow>> rssListReadRecordsByOrigin(
    String origin, [
    int? limit,
  ]) async {
    return (await bridge.rssListReadRecordsByOrigin(
      origin: origin,
      limit: limit == null ? null : businessI32(limit),
    )).map(rssReadFromDto).toList();
  }
}
