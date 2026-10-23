import '../bridge/rust_errors.dart';

import 'package:flutter_rust_bridge/flutter_rust_bridge.dart' show Int64List;

import '../../bridge/ffi/ffi.dart' as bridge;
import '../../bridge/transfer_dto.dart' as dto;
import '../../domain/contracts/read_record_repository.dart';
import '../../domain/contracts/read_record_changes.dart';
import '../../models/misc.dart';
import '../../models/read_record_detail.dart';
import '../../models/read_record_session.dart';
import '../../domain/models/read_record_timeline_entry.dart';
import '../bridge/reading_dto_mapping.dart';

/// 直接调用已有 FRB；复用应用已初始化的运行时和数据库。— Codex + Bridge
final class RustReadRecordRepository
    with ReadRecordChangeNotifications
    implements ReadRecordRepository {
  RustReadRecordRepository();

  @override
  Future<List<ReadRecord>> getReadRecords() async {
    return (await rustFuture(
      () => bridge.readRecordList(),
      operation: 'readRecordList',
    )).map(readRecordFromDto).toList();
  }

  @override
  Future<void> putReadRecord(
    ReadRecord record, {
    String bookUrl = '',
    int chapterIndex = 0,
  }) async {
    await rustFuture(
      () => bridge.readRecordRecordTime(
        bookName: record.bookName,
        author: record.author,
        readTimeMs: record.readTime,
        startTimeMs: record.startTime,
        bookUrl: bookUrl,
        chapterIndex: chapterIndex,
        endTimeMs: record.lastRead > 0 ? record.lastRead : null,
      ),
      operation: 'readRecordRecordTime',
    );
    notifyReadRecordChanged();
  }

  @override
  Future<void> deleteReadRecord(String bookName, {String? author}) async {
    if (author == null) {
      await rustFuture(
        () => bridge.readRecordDelete(bookName: bookName),
        operation: 'readRecordDelete',
      );
    } else {
      await rustFuture(
        () => bridge.readRecordDeleteWithAuthor(
          bookName: bookName,
          author: author,
        ),
        operation: 'readRecordDeleteWithAuthor',
      );
    }
    notifyReadRecordChanged();
  }

  @override
  Future<void> clearReadRecords() async {
    await rustFuture(
      () => bridge.readRecordClear(),
      operation: 'readRecordClear',
    );
    notifyReadRecordChanged();
  }

  @override
  Future<List<Map<String, dynamic>>> readRecordDailyList(int year) async {
    return (await rustFuture(
          () => bridge.readRecordDailyList(year: year),
          operation: 'readRecordDailyList',
        ))
        .map(
          (value) => <String, dynamic>{
            'date': value.date,
            'seconds': value.seconds,
          },
        )
        .toList();
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
      (await rustFuture(
        () => bridge.readRecordDetailList(year: year),
        operation: 'readRecordDetailList',
      )).map(_detailFromDto).toList();

  @override
  Future<List<ReadRecordDetail>> getAllReadRecordDetails() async =>
      (await rustFuture(
        () => bridge.readRecordAllDetailList(),
        operation: 'readRecordAllDetailList',
      )).map(_detailFromDto).toList();

  @override
  Future<List<ReadRecordSession>> getReadRecordSessions() async {
    return (await rustFuture(
      () => bridge.readRecordSessionList(),
      operation: 'readRecordSessionList',
    )).map(readRecordSessionFromDto).toList();
  }

  @override
  Future<List<ReadRecordTimelineEntry>> getReadRecordTimeline(
    String query,
  ) async =>
      (await rustFuture(
            () => bridge.readRecordTimeline(query: query),
            operation: 'readRecordTimeline',
          ))
          .map(
            (row) => ReadRecordTimelineEntry(
              bookName: row.bookName,
              author: row.author,
              date: row.date,
              bookUrl: row.bookUrl,
              startTime: row.startTime,
              endTime: row.endTime,
              chapterIndex: row.chapterIndex,
              sessionIds: List.unmodifiable(
                row.sessionIds.map((id) => id.toInt()),
              ),
            ),
          )
          .toList();

  @override
  Future<void> deleteReadRecordDetail(
    String bookName,
    String author,
    String date,
  ) async {
    await rustFuture(
      () => bridge.readRecordDetailDelete(
        bookName: bookName,
        author: author,
        date: date,
      ),
      operation: 'readRecordDetailDelete',
    );
    notifyReadRecordChanged();
  }

  @override
  Future<void> deleteReadRecordSessions(List<int> ids) async {
    await rustFuture(
      () => bridge.readRecordSessionsDelete(ids: Int64List.fromList(ids)),
      operation: 'readRecordSessionsDelete',
    );
    notifyReadRecordChanged();
  }
}
