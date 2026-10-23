import 'dart:math' as math;

import '../../domain/contracts/read_record_repository.dart';
import '../../domain/models/read_record_timeline_entry.dart';
import '../../domain/models/read_record_statistics.dart';
import '../../domain/models/read_record_list.dart';
import '../../domain/contracts/read_record_changes.dart';
import '../../models/models.dart';
import '../../models/read_record_identity.dart';

/// Mock 保持相同的累计、每日明细与变更通知语义。— Codex + UI
class MockReadRecordRepository
    with ReadRecordChangeNotifications
    implements ReadRecordRepository {
  final List<ReadRecord> _readRecords = [];
  final List<ReadRecordSession> _sessions = [];
  int _nextSessionId = 1;
  final Map<(String, String, String), ReadRecordDetail> _details = {};

  @override
  Future<List<ReadRecord>> getReadRecords() async => List.from(_readRecords);

  @override
  Future<void> putReadRecord(
    ReadRecord record, {
    String bookUrl = '',
    int chapterIndex = 0,
  }) async {
    if (record.readTime < 0) throw ArgumentError('累计阅读时长不能为负数');
    final previous = _readRecords
        .where((r) => r.bookName == record.bookName)
        .firstOrNull;
    final delta = record.readTime - (previous?.readTime ?? 0);
    if (delta <= 0) return;
    final end = record.lastRead > 0
        ? record.lastRead
        : DateTime.now().millisecondsSinceEpoch;
    var cursor = end - delta;
    if (record.startTime != null && record.startTime! > cursor) {
      throw ArgumentError('阅读时段短于有效增量');
    }
    _sessions.add(
      ReadRecordSession(
        id: _nextSessionId++,
        bookName: record.bookName,
        author: record.author,
        bookUrl: bookUrl,
        startTime: end - delta,
        endTime: end,
        chapterIndex: chapterIndex < 0 ? 0 : chapterIndex,
      ),
    );
    while (cursor < end) {
      final date = DateTime.fromMillisecondsSinceEpoch(cursor);
      final midnight = DateTime(
        date.year,
        date.month,
        date.day + 1,
      ).millisecondsSinceEpoch;
      final next = math.min(end, midnight);
      final keyDate =
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final key = (record.bookName, record.author, keyDate);
      final old = _details[key];
      _details[key] = ReadRecordDetail(
        bookName: record.bookName,
        author: record.author,
        date: keyDate,
        readTime: (old?.readTime ?? 0) + next - cursor,
        lastRead: math.max(old?.lastRead ?? 0, next),
      );
      cursor = next;
    }
    _readRecords.removeWhere((r) => r.bookName == record.bookName);
    _readRecords.add(
      record.copyWith(
        author: mergeReadRecordAuthors(previous?.author ?? '', record.author),
        startTime: null,
      ),
    );
    notifyReadRecordChanged();
  }

  @override
  Future<void> deleteReadRecord(String bookName, {String? author}) async {
    final removed = _details.values
        .where(
          (d) =>
              d.bookName == bookName && (author == null || d.author == author),
        )
        .fold<int>(0, (sum, d) => sum + d.readTime);
    _details.removeWhere(
      (key, _) => key.$1 == bookName && (author == null || key.$2 == author),
    );
    _sessions.removeWhere(
      (s) => s.bookName == bookName && (author == null || s.author == author),
    );
    if (author == null) {
      _readRecords.removeWhere((r) => r.bookName == bookName);
    } else {
      _deductTotal(bookName, removed);
    }
    notifyReadRecordChanged();
  }

  @override
  Future<void> clearReadRecords() async {
    _readRecords.clear();
    _sessions.clear();
    _details.clear();
    notifyReadRecordChanged();
  }

  @override
  Future<List<Map<String, dynamic>>> readRecordDailyList(int year) async {
    final times = <String, int>{};
    for (final d in await getReadRecordDetails(year)) {
      times[d.date] = (times[d.date] ?? 0) + d.readTime;
    }
    return (times.keys.toList()..sort())
        .map(
          (date) => <String, dynamic>{
            'date': date,
            'seconds': times[date]! ~/ 1000,
          },
        )
        .toList();
  }

  @override
  Future<List<ReadRecordDetail>> getReadRecordDetails(int year) async =>
      (await getAllReadRecordDetails())
          .where(
            (d) => d.date.startsWith('${year.toString().padLeft(4, '0')}-'),
          )
          .toList();

  @override
  Future<List<ReadRecordDetail>> getAllReadRecordDetails() async =>
      _details.values.toList()..sort((a, b) => a.date.compareTo(b.date));
  @override
  Future<ReadRecordStatistics> getReadRecordOverview(
    ReadPeriod period,
    DateTime date,
  ) => Future.error(UnsupportedError('Mock未提供阅读统计，请注入结果夹具'));
  @override
  Future<List<ReadBookRanking>> getReadRecordBooksForDay(DateTime date) =>
      Future.error(UnsupportedError('Mock未提供当天统计，请注入结果夹具'));

  @override
  Future<List<int>> getReadRecordHourly(List<int> boundaries) =>
      Future.error(UnsupportedError('Mock未提供小时统计，请注入结果夹具'));

  @override
  Future<ReadRecordListData> getReadRecordList(String query) =>
      Future.error(UnsupportedError('Mock未提供阅读列表，请注入结果夹具'));

  @override
  Future<List<ReadRecordTimelineEntry>> getReadRecordTimeline(String query) =>
      Future.error(UnsupportedError('Mock未提供阅读时间线，请注入时间线夹具'));

  @override
  Future<List<ReadRecordSession>> getReadRecordSessions() async =>
      List.of(_sessions)..sort((a, b) => a.startTime.compareTo(b.startTime));

  void _deductTotal(String name, int duration) {
    final old = _readRecords.where((r) => r.bookName == name).firstOrNull;
    if (old == null) return;
    _readRecords.removeWhere((r) => r.bookName == name);
    final remaining = _details.values.where((d) => d.bookName == name).toList();
    if (old.readTime > duration) {
      _readRecords.add(
        old.copyWith(
          readTime: old.readTime - duration,
          author: remaining.fold<String>(
            '',
            (value, d) => mergeReadRecordAuthors(value, d.author),
          ),
          lastRead: remaining.fold<int>(
            0,
            (value, d) => math.max(value, d.lastRead),
          ),
        ),
      );
    }
  }

  void _deductDetail(String name, String author, String date, int duration) {
    final key = (name, author, date);
    final old = _details[key];
    if (old == null) return;
    if (old.readTime <= duration) {
      _details.remove(key);
    } else {
      _details[key] = ReadRecordDetail(
        bookName: name,
        author: author,
        date: date,
        readTime: old.readTime - duration,
        lastRead: old.lastRead,
      );
    }
  }

  @override
  Future<void> deleteReadRecordSessions(List<int> ids) async {
    final selected = _sessions.where((s) => ids.contains(s.id)).toList();
    _sessions.removeWhere((s) => ids.contains(s.id));
    for (final s in selected) {
      var cursor = s.startTime;
      while (cursor < s.endTime) {
        final date = DateTime.fromMillisecondsSinceEpoch(cursor);
        final end = math.min(
          s.endTime,
          DateTime(date.year, date.month, date.day + 1).millisecondsSinceEpoch,
        );
        final key =
            '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        _deductDetail(s.bookName, s.author, key, end - cursor);
        cursor = end;
      }
      _deductTotal(s.bookName, s.durationMs);
    }
    notifyReadRecordChanged();
  }

  @override
  Future<void> deleteReadRecordDetail(
    String bookName,
    String author,
    String date,
  ) async {
    final day = DateTime.parse(date);
    final start = DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
    final end = DateTime(
      day.year,
      day.month,
      day.day + 1,
    ).millisecondsSinceEpoch;
    final old = _details.remove((bookName, author, date));
    if (old == null) return;
    final selected = _sessions
        .where(
          (s) =>
              s.bookName == bookName &&
              s.author == author &&
              s.startTime < end &&
              s.endTime > start,
        )
        .toList();
    _sessions.removeWhere(selected.contains);
    for (final s in selected) {
      if (s.startTime < start) {
        _sessions.add(
          s.withInterval(
            _nextSessionId++,
            s.startTime,
            math.min(s.endTime, start),
          ),
        );
      }
      if (s.endTime > end) {
        _sessions.add(
          s.withInterval(
            _nextSessionId++,
            math.max(s.startTime, end),
            s.endTime,
          ),
        );
      }
    }
    _deductTotal(bookName, old.readTime);
    notifyReadRecordChanged();
  }
}
