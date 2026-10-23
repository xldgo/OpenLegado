import '../../models/misc.dart';
import '../../models/read_record_detail.dart';
import '../../models/read_record_session.dart';
import '../models/read_record_timeline_entry.dart';
import '../models/read_record_statistics.dart';

/// 阅读记录的数据访问契约；累计与持久化规则由底层负责。— Codex + UI
abstract interface class ReadRecordRepository {
  Future<List<ReadRecord>> getReadRecords();

  /// 写入累计毫秒；正式实现由 Rust 更新最后阅读时间与每日秒数。
  Future<void> putReadRecord(
    ReadRecord record, {
    String bookUrl = '',
    int chapterIndex = 0,
  });

  Future<void> deleteReadRecord(String bookName, {String? author});

  Future<void> clearReadRecords();

  /// 按年查询日期升序的每日时长，返回 date 与 seconds 字段。
  Future<List<Map<String, dynamic>>> readRecordDailyList(int year);

  Future<List<ReadRecordDetail>> getReadRecordDetails(int year);

  Future<List<ReadRecordDetail>> getAllReadRecordDetails();
  Future<List<ReadRecordSession>> getReadRecordSessions();
  Future<List<ReadRecordTimelineEntry>> getReadRecordTimeline(String query);
  Future<ReadRecordStatistics> getReadRecordOverview(
    ReadPeriod period,
    DateTime date,
  );
  Future<List<ReadBookRanking>> getReadRecordBooksForDay(DateTime date);
  Future<List<int>> getReadRecordHourly(List<int> boundaries);

  Future<void> deleteReadRecordDetail(
    String bookName,
    String author,
    String date,
  );
  Future<void> deleteReadRecordSessions(List<int> ids);
}
