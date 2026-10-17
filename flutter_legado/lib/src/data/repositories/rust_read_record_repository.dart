import 'package:flutter_rust_bridge/flutter_rust_bridge.dart' show Int64List;

import '../../bridge/ffi/ffi.dart' as bridge;
import '../../bridge/transfer_dto.dart' as dto;
import '../../domain/contracts/read_record_repository.dart';
import '../../domain/contracts/read_record_changes.dart';
import '../../models/misc.dart';
import '../../models/read_record_detail.dart';
import '../../models/read_record_session.dart';
import '../bridge/rust_json_decode.dart';

/// 直接调用已有 FRB；复用应用已初始化的运行时和数据库。— Codex + Bridge
final class RustReadRecordRepository
    with ReadRecordChangeNotifications
    implements ReadRecordRepository {
  RustReadRecordRepository();

  @override
  Future<List<ReadRecord>> getReadRecords() async {
    final json = await bridge.readRecordList();
    return decodeRustJsonList(
      json,
      'bookApi',
    ).map((item) => ReadRecord.fromJson(item as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> putReadRecord(
    ReadRecord record, {
    String bookUrl = '',
    int chapterIndex = 0,
  }) async {
    await bridge.readRecordRecordTime(
      bookName: record.bookName,
      author: record.author,
      readTimeMs: record.readTime,
      startTimeMs: record.startTime,
      bookUrl: bookUrl,
      chapterIndex: chapterIndex,
      endTimeMs: record.lastRead > 0 ? record.lastRead : null,
    );
    notifyReadRecordChanged();
  }

  @override
  Future<void> deleteReadRecord(String bookName, {String? author}) async {
    if (author == null) {
      await bridge.readRecordDelete(bookName: bookName);
    } else {
      await bridge.readRecordDeleteWithAuthor(
        bookName: bookName,
        author: author,
      );
    }
    notifyReadRecordChanged();
  }

  @override
  Future<void> clearReadRecords() async {
    await bridge.readRecordClear();
    notifyReadRecordChanged();
  }

  @override
  Future<List<Map<String, dynamic>>> readRecordDailyList(int year) async {
    final json = await bridge.readRecordDailyList(year: year);
    return decodeRustJsonList(json, 'bookApi').cast<Map<String, dynamic>>();
  }

  ReadRecordDetail _detailFromDto(dto.ReadRecordDetailDto value) =>
      ReadRecordDetail(
        bookName: value.bookName,
        author: value.author,
        date: value.date,
        readTime: value.readTime,
        lastRead: value.lastRead,
      );

  @override
  Future<List<ReadRecordDetail>> getReadRecordDetails(int year) async =>
      (await bridge.readRecordDetailList(year: year))
          .map(_detailFromDto)
          .toList();

  @override
  Future<List<ReadRecordDetail>> getAllReadRecordDetails() async =>
      (await bridge.readRecordAllDetailList()).map(_detailFromDto).toList();

  @override
  Future<List<ReadRecordSession>> getReadRecordSessions() async {
    final json = await bridge.readRecordSessionList();
    return decodeRustJsonList(json, 'readRecord')
        .map((item) => ReadRecordSession.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> deleteReadRecordDetail(
    String bookName,
    String author,
    String date,
  ) async {
    await bridge.readRecordDetailDelete(
      bookName: bookName,
      author: author,
      date: date,
    );
    notifyReadRecordChanged();
  }

  @override
  Future<void> deleteReadRecordSessions(List<int> ids) async {
    await bridge.readRecordSessionsDelete(ids: Int64List.fromList(ids));
    notifyReadRecordChanged();
  }
}
