import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/read_record_repository.dart';
import '../../models/misc.dart';
import '../bridge/rust_json_decode.dart';

/// 直接调用已有 FRB；复用应用已初始化的运行时和数据库。— Codex + Bridge
final class RustReadRecordRepository implements ReadRecordRepository {
  const RustReadRecordRepository();

  @override
  Future<List<ReadRecord>> getReadRecords() async {
    final json = await bridge.readRecordList();
    return decodeRustJsonList(
      json,
      'bookApi',
    ).map((item) => ReadRecord.fromJson(item as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> putReadRecord(ReadRecord record) async {
    await bridge.readRecordUpsert(
      bookName: record.bookName,
      readTime: record.readTime,
    );
  }

  @override
  Future<void> deleteReadRecord(String bookName) async {
    await bridge.readRecordDelete(bookName: bookName);
  }

  @override
  Future<void> clearReadRecords() async {
    await bridge.readRecordClear();
  }

  @override
  Future<List<Map<String, dynamic>>> readRecordDailyList(int year) async {
    final json = await bridge.readRecordDailyList(year: year);
    return decodeRustJsonList(json, 'bookApi').cast<Map<String, dynamic>>();
  }
}
