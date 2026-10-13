import '../../domain/contracts/read_record_repository.dart';
import '../../models/misc.dart';

/// Mock 会话的唯一阅读记录存储；保留原按书名替换语义。— Codex + UI
class MockReadRecordRepository implements ReadRecordRepository {
  final List<ReadRecord> _readRecords = [];

  @override
  Future<List<ReadRecord>> getReadRecords() async => List.from(_readRecords);

  @override
  Future<void> putReadRecord(ReadRecord record) async {
    _readRecords.removeWhere((r) => r.bookName == record.bookName);
    _readRecords.add(record);
  }

  @override
  Future<void> deleteReadRecord(String bookName) async {
    _readRecords.removeWhere((r) => r.bookName == bookName);
  }

  @override
  Future<void> clearReadRecords() async {
    _readRecords.clear();
  }

  @override
  Future<List<Map<String, dynamic>>> readRecordDailyList(int year) async =>
      const [];
}
