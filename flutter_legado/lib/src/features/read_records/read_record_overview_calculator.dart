import '../../models/read_record_identity.dart';
import '../../models/models.dart';
import 'read_record_overview_state.dart';

/// 对照上游 GetReadRecordOverviewUseCase 的纯统计计算。— Codex + UI
class ReadRecordOverviewCalculator {
  static DateTime? parseDate(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) return null;
    final year = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final day = int.parse(match[3]!);
    final date = DateTime(year, month, day);
    return date.year == year && date.month == month && date.day == day
        ? date
        : null;
  }

  static String dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static (DateTime, DateTime) getPeriodRange(
    ReadPeriod period,
    DateTime refDate,
  ) {
    final base = DateTime(refDate.year, refDate.month, refDate.day);
    return switch (period) {
      ReadPeriod.day => (base, base),
      ReadPeriod.week => (
        DateTime(base.year, base.month, base.day - base.weekday + 1),
        DateTime(base.year, base.month, base.day + 7 - base.weekday),
      ),
      ReadPeriod.month => (
        DateTime(base.year, base.month, 1),
        DateTime(base.year, base.month + 1, 0),
      ),
      ReadPeriod.year => (
        DateTime(base.year, 1, 1),
        DateTime(base.year, 12, 31),
      ),
      ReadPeriod.all => (DateTime(1, 1, 1), DateTime(9999, 12, 31)),
    };
  }

  static DateTime stepDate(ReadPeriod period, DateTime date, int step) {
    if (period == ReadPeriod.all) return date;
    if (period == ReadPeriod.day || period == ReadPeriod.week) {
      return DateTime(
        date.year,
        date.month,
        date.day + step * (period == ReadPeriod.week ? 7 : 1),
      );
    }
    final first = DateTime(
      date.year + (period == ReadPeriod.year ? step : 0),
      date.month + (period == ReadPeriod.month ? step : 0),
      1,
    );
    final maxDay = DateTime(first.year, first.month + 1, 0).day;
    return DateTime(first.year, first.month, date.day.clamp(1, maxDay));
  }

  static Set<String> authors(String value) => readRecordAuthors(value);

  /// 当天全部单书明细：合并同作者书籍的设备记录，不截取排行榜前十。
  static List<ReadBookRanking> booksForDay({
    required DateTime date,
    required List<ReadRecordDetail> details,
    required List<Book> shelfBooks,
  }) {
    final key = dateKey(date);
    final totals = <(String, String), int>{};
    for (final detail in details) {
      if (detail.date != key || detail.readTime <= 0) continue;
      final book = (detail.bookName, detail.author);
      totals[book] = (totals[book] ?? 0) + detail.readTime;
    }
    final shelf = <(String, String), Book>{
      for (final book in shelfBooks) (book.name, book.author): book,
    };
    final books =
        totals.entries
            .map(
              (entry) => ReadBookRanking(
                bookName: entry.key.$1,
                author: entry.key.$2,
                readTimeMs: entry.value,
                coverUrl: shelf[entry.key]?.coverUrl,
              ),
            )
            .toList()
          ..sort((a, b) {
            final duration = b.readTimeMs.compareTo(a.readTimeMs);
            if (duration != 0) return duration;
            final name = a.bookName.compareTo(b.bookName);
            return name != 0 ? name : a.author.compareTo(b.author);
          });
    return List.unmodifiable(books);
  }

  /// 用真实会话与本地小时区间求交集；不从每日累计量推算小时分布。
  static List<({DateTime date, int seconds})> hourlyDistribution(
    DateTime date,
    List<ReadRecordSession> sessions,
  ) {
    final boundaries = List.generate(
      25,
      (hour) => DateTime(date.year, date.month, date.day, hour),
    );
    final milliseconds = List.filled(24, 0);
    final dayStart = boundaries.first.millisecondsSinceEpoch;
    final dayEnd = boundaries.last.millisecondsSinceEpoch;
    for (final session in sessions) {
      if (session.endTime <= session.startTime ||
          session.endTime <= dayStart ||
          session.startTime >= dayEnd) {
        continue;
      }
      for (var hour = 0; hour < 24; hour++) {
        final start = session.startTime.clamp(
          boundaries[hour].millisecondsSinceEpoch,
          boundaries[hour + 1].millisecondsSinceEpoch,
        );
        final end = session.endTime.clamp(
          boundaries[hour].millisecondsSinceEpoch,
          boundaries[hour + 1].millisecondsSinceEpoch,
        );
        milliseconds[hour] += end - start;
      }
    }
    return List.generate(
      24,
      (hour) => (date: boundaries[hour], seconds: milliseconds[hour] ~/ 1000),
    );
  }

  static ReadRecordOverviewState compute({
    required ReadPeriod period,
    required DateTime referenceDate,
    required List<ReadRecordDetail> details,
    required List<ReadRecord> records,
    required List<Book> shelfBooks,
    List<ReadRecordSession> sessions = const [],
  }) {
    final refDate = DateTime(
      referenceDate.year,
      referenceDate.month,
      referenceDate.day,
    );
    final (start, end) = getPeriodRange(period, refDate);
    // 先合并跨设备相同书籍同日的明细，再按周期计算；不使用累计排行推算每日数据。
    final byDate = <String, Map<(String, String), int>>{};
    final orderedDetails = [...details]
      ..sort((a, b) {
        final dateOrder = b.date.compareTo(a.date);
        return dateOrder != 0 ? dateOrder : b.lastRead.compareTo(a.lastRead);
      });
    for (final d in orderedDetails) {
      if (d.readTime <= 0 || parseDate(d.date) == null) continue;
      final books = byDate.putIfAbsent(d.date, () => {});
      final key = (d.bookName, d.author);
      books[key] = (books[key] ?? 0) + d.readTime;
    }
    final periodBooks = <(String, String), int>{};
    final periodDays = <String, int>{};
    final allTimes = <String, int>{};
    final allCounts = <String, int>{};
    final topByDay =
        <String, ({String bookName, String author, String? coverUrl})>{};
    final shelf = <(String, String), Book>{
      for (final b in shelfBooks) (b.name, b.author): b,
    };
    for (final entry in byDate.entries) {
      final date = parseDate(entry.key)!;
      final total = entry.value.values.fold<int>(0, (sum, v) => sum + v);
      allTimes[entry.key] = total ~/ 1000;
      allCounts[entry.key] = entry.value.length;
      final top = entry.value.entries
          .reduce((a, b) => a.value >= b.value ? a : b)
          .key;
      topByDay[entry.key] = (
        bookName: top.$1,
        author: top.$2,
        coverUrl: shelf[top]?.coverUrl,
      );
      if (period == ReadPeriod.all ||
          (!date.isBefore(start) && !date.isAfter(end))) {
        periodDays[entry.key] = total;
        for (final book in entry.value.entries) {
          periodBooks[book.key] = (periodBooks[book.key] ?? 0) + book.value;
        }
      }
    }
    final latestKeys = <(String, String)>{
      for (final r in records)
        for (final author in authors(r.author)) (r.bookName, author),
    };
    var reading = 0;
    var finished = 0;
    for (final key in periodBooks.keys) {
      if (latestKeys.contains(key)) reading++;
      final book = shelf[key];
      if (book != null &&
          book.totalChapterNum > 0 &&
          book.durChapterIndex >= book.totalChapterNum - 1 &&
          book.durChapterPos != 0) {
        finished++;
      }
    }
    final sorted = periodBooks.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final chart = <({DateTime date, int seconds})>[];
    if (period == ReadPeriod.day) {
      chart.addAll(hourlyDistribution(refDate, sessions));
    } else if (period == ReadPeriod.year) {
      for (var month = 1; month <= 12; month++) {
        final total = periodDays.entries
            .where((e) => parseDate(e.key)!.month == month)
            .fold<int>(0, (s, e) => s + e.value);
        chart.add((
          date: DateTime(refDate.year, month, 1),
          seconds: total ~/ 1000,
        ));
      }
    } else if (period != ReadPeriod.all) {
      for (
        var day = start;
        !day.isAfter(end);
        day = DateTime(day.year, day.month, day.day + 1)
      ) {
        chart.add((
          date: day,
          seconds: (periodDays[dateKey(day)] ?? 0) ~/ 1000,
        ));
      }
    }
    return ReadRecordOverviewState(
      period: period,
      referenceDate: refDate,
      totalTimeMs: period == ReadPeriod.all
          ? records.fold<int>(0, (s, r) => s + r.readTime)
          : periodDays.values.fold<int>(0, (s, v) => s + v),
      readingDays: periodDays.length,
      totalBooks: periodBooks.length,
      finishedBooks: finished,
      readingBooks: reading,
      topBooks: sorted
          .take(10)
          .map(
            (e) => ReadBookRanking(
              bookName: e.key.$1,
              author: e.key.$2,
              readTimeMs: e.value,
              coverUrl: shelf[e.key]?.coverUrl,
            ),
          )
          .toList(),
      dailyTimeData: chart,
      dailyTopBook: topByDay,
      allDailyTimes: allTimes,
      allDailyCounts: allCounts,
    );
  }
}
