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
import '../../domain/models/read_record_statistics.dart';
import '../../bridge/statistics_dto.dart' as statistics;
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

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  ReadBookRanking _ranking(statistics.ReadBookRankingDto row) =>
      ReadBookRanking(
        bookName: row.bookName,
        author: row.author,
        readTimeMs: row.readTimeMs,
        coverUrl: row.coverUrl,
      );
  @override
  Future<List<ReadBookRanking>> getReadRecordBooksForDay(DateTime date) async =>
      (await rustFuture(
        () => bridge.readRecordBooksForDay(date: _dateKey(date)),
        operation: 'readRecordBooksForDay',
      )).map(_ranking).toList();
  @override
  Future<ReadRecordStatistics> getReadRecordOverview(
    ReadPeriod period,
    DateTime date,
  ) async {
    final result = await rustFuture(
      () => bridge.readRecordOverview(
        period: switch (period) {
          ReadPeriod.day => statistics.ReadRecordPeriodDto.day,
          ReadPeriod.week => statistics.ReadRecordPeriodDto.week,
          ReadPeriod.month => statistics.ReadRecordPeriodDto.month,
          ReadPeriod.year => statistics.ReadRecordPeriodDto.year,
          ReadPeriod.all => statistics.ReadRecordPeriodDto.all,
        },
        referenceDate: _dateKey(date),
      ),
      operation: 'readRecordOverview',
    );
    return ReadRecordStatistics(
      totalTimeMs: result.totalTimeMs,
      readingDays: result.readingDays,
      totalBooks: result.totalBooks,
      finishedBooks: result.finishedBooks,
      readingBooks: result.readingBooks,
      topBooks: result.topBooks.map(_ranking).toList(),
      dailyTimeData: result.chart
          .map((p) => (date: DateTime.parse(p.date), seconds: p.seconds))
          .toList(),
      allDailyTimes: {for (final day in result.days) day.date: day.seconds},
      allDailyCounts: {for (final day in result.days) day.date: day.bookCount},
      dailyTopBook: {
        for (final day in result.days)
          day.date: (
            bookName: day.topBook.bookName,
            author: day.topBook.author,
            coverUrl: day.topBook.coverUrl,
          ),
      },
    );
  }

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
