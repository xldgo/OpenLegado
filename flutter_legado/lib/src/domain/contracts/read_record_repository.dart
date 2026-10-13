import '../../models/misc.dart';

/// 阅读记录的数据访问契约；累计与持久化规则由底层负责。— Codex + UI
abstract interface class ReadRecordRepository {
  Future<List<ReadRecord>> getReadRecords();

  /// 写入累计毫秒；正式实现由 Rust 更新最后阅读时间与每日秒数。
  Future<void> putReadRecord(ReadRecord record);

  Future<void> deleteReadRecord(String bookName);

  Future<void> clearReadRecords();

  /// 按年查询日期升序的每日时长，返回 date 与 seconds 字段。
  Future<List<Map<String, dynamic>>> readRecordDailyList(int year);
}
