import '../../domain/contracts/rss_read_record_repository.dart';
import '../../models/models.dart';

/// 订阅Mock使用装配实例内的同一份数据。— Codex + Bridge
final class MockRssReadRecordRepository implements RssReadRecordRepository {
  final Set<String> _rssReadLinks = {};
  final List<RssReadRecordRow> _rssReadRecords = [];

  @override
  Future<void> rssMarkRead(String origin, String title, [String? link]) async {
    if (link != null) _rssReadLinks.add(link);
    _rssReadRecords.insert(
      0,
      RssReadRecordRow(
        origin: origin,
        title: title,
        link: link,
        readTime: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  @override
  Future<bool> rssIsRead(String link) async => _rssReadLinks.contains(link);

  @override
  Future<bool> rssIsReadByTitle(String origin, String title) async =>
      _rssReadRecords.any((r) => r.origin == origin && r.title == title);

  @override
  Future<void> rssClearReadRecords() async {
    _rssReadLinks.clear();
    _rssReadRecords.clear();
  }

  @override
  Future<int> rssReadRecordCount() async => _rssReadRecords.length;

  @override
  Future<List<RssReadRecordRow>> rssListReadRecords([int? limit]) async {
    final l = limit ?? 100;
    return _rssReadRecords.take(l).toList();
  }

  @override
  Future<List<RssReadRecordRow>> rssListReadRecordsByOrigin(
    String origin, [
    int? limit,
  ]) async {
    final l = limit ?? 100;
    return _rssReadRecords.where((r) => r.origin == origin).take(l).toList();
  }
}
