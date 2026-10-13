import 'package:flutter_riverpod/flutter_riverpod.dart'
    hide Provider;

import '../../models/models.dart';
import '../bookshelf/bookshelf.dart';
import 'read_record_notifier.dart';
import 'read_record_overview_state.dart';
import 'read_record_repository_provider.dart';

/// 阅读总览 Notifier（对齐上游 ReadRecordOverviewViewModel + GetReadRecordOverviewUseCase）
///
/// 依赖：
/// - [readRecordNotifierProvider]：最新合并阅读记录列表（ReadRecordShow）
/// - [readRecordRepositoryProvider]：按年查询每日阅读时长详情
/// - [bookshelfNotifierProvider]：书架书籍列表（用于匹配已读完/在读判断与封面）
class ReadRecordOverviewNotifier extends Notifier<ReadRecordOverviewState> {
  Map<String, int> _cachedDailyMap = const {};
  int? _cachedYear;
  bool _isLoading = false;

  @override
  ReadRecordOverviewState build() {
    // 监听书架状态变动与阅读记录汇总变动时自动重新计算
    final readRecordState = ref.watch(readRecordNotifierProvider);
    final shelfState = ref.watch(bookshelfNotifierProvider);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_cachedDailyMap.isNotEmpty) {
      final prevPeriod = stateOrNull?.period ?? ReadPeriod.day;
      final prevRef = stateOrNull?.referenceDate ?? today;
      return computeOverview(
        period: prevPeriod,
        referenceDate: prevRef,
        dailyRecords: _cachedDailyMap,
        records: readRecordState.records,
        shelfBooks: shelfState.books,
      );
    }

    final initialState = ReadRecordOverviewState(referenceDate: today);

    // 初始异步加载详情并计算
    Future.microtask(() => refresh());

    return initialState;
  }

  /// 切换统计周期
  void setPeriod(ReadPeriod period) {
    if (state.period == period) return;
    state = state.copyWith(period: period);
    refresh();
  }

  /// 上一周期（对齐 ViewModel prevDate）
  void previousPeriod() {
    final current = state.referenceDate;
    final nextDate = switch (state.period) {
      ReadPeriod.day => current.subtract(const Duration(days: 1)),
      ReadPeriod.week => current.subtract(const Duration(days: 7)),
      ReadPeriod.month => DateTime(current.year, current.month - 1, current.day),
      ReadPeriod.year => DateTime(current.year - 1, current.month, current.day),
      ReadPeriod.all => current,
    };
    state = state.copyWith(referenceDate: nextDate);
    refresh();
  }

  /// 下一周期（对齐 ViewModel nextDate）
  void nextPeriod() {
    final current = state.referenceDate;
    final nextDate = switch (state.period) {
      ReadPeriod.day => current.add(const Duration(days: 1)),
      ReadPeriod.week => current.add(const Duration(days: 7)),
      ReadPeriod.month => DateTime(current.year, current.month + 1, current.day),
      ReadPeriod.year => DateTime(current.year + 1, current.month, current.day),
      ReadPeriod.all => current,
    };
    state = state.copyWith(referenceDate: nextDate);
    refresh();
  }

  /// 重新刷新并计算指标
  Future<void> refresh() async {
    if (_isLoading) return;
    _isLoading = true;
    state = state.copyWith(isLoading: true);

    try {
      final repository = ref.read(readRecordRepositoryProvider);
      final refYear = state.referenceDate.year;

      if (_cachedYear != refYear || _cachedDailyMap.isEmpty) {
        final dailyListCurrentYear =
            await repository.readRecordDailyList(refYear);
        final dailyMap = <String, int>{};
        for (final item in dailyListCurrentYear) {
          final date = (item['date'] ?? '').toString();
          if (date.isEmpty) continue;
          final sec = (item['seconds'] as num?)?.toInt() ?? 0;
          dailyMap[date] = sec;
        }
        _cachedDailyMap = dailyMap;
        _cachedYear = refYear;
      }

      final readRecordState = ref.read(readRecordNotifierProvider);
      final shelfState = ref.read(bookshelfNotifierProvider);

      final calculated = computeOverview(
        period: state.period,
        referenceDate: state.referenceDate,
        dailyRecords: _cachedDailyMap,
        records: readRecordState.records,
        shelfBooks: shelfState.books,
      );

      state = calculated.copyWith(isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    } finally {
      _isLoading = false;
    }
  }

  /// 核心纯计算逻辑（对齐 GetReadRecordOverviewUseCase.kt）
  static ReadRecordOverviewState computeOverview({
    required ReadPeriod period,
    required DateTime referenceDate,
    required Map<String, int> dailyRecords,
    required List<ReadRecordShow> records,
    required List<Book> shelfBooks,
  }) {
    final refDate = DateTime(
      referenceDate.year,
      referenceDate.month,
      referenceDate.day,
    );
    final (startDate, endDate) = getPeriodRange(period, refDate);

    // 过滤出本周期的 dailyRecords（date: YYYY-MM-DD -> seconds）
    final filteredDaily = <String, int>{};
    for (final entry in dailyRecords.entries) {
      if (entry.value <= 0) continue;
      final parsed = _parseIsoDate(entry.key);
      if (parsed == null) continue;
      if (period == ReadPeriod.all) {
        filteredDaily[entry.key] = entry.value;
      } else {
        if (!parsed.isBefore(startDate) && !parsed.isAfter(endDate)) {
          filteredDaily[entry.key] = entry.value;
        }
      }
    }

    // 1. 总时长与天数计算
    // 对齐上游口径：all 模式使用合并后的 readRecord 汇总；周期模式根据 filteredDaily 汇总毫秒
    final totalTimeMs = period == ReadPeriod.all
        ? records.fold<int>(0, (sum, r) => sum + r.readTime)
        : filteredDaily.values.fold<int>(0, (sum, sec) => sum + (sec * 1000));

    final readingDays = filteredDaily.keys.length;

    // 2. 本周期书籍统计与排行
    // records 作为书籍阅读时长池
    // 书架映射
    final shelfMap = <String, Book>{};
    for (final b in shelfBooks) {
      shelfMap[b.name] = b;
    }

    // 在本周期读过的书籍（如果 period == all，所有 records；周期模式下根据时长>0过滤）
    // 周期模式下按比例或按已有 records 过滤。在移动端无单本每日详情分表时，
    // 若总阅读时长>0 且在本周期有 readingDays，书籍按 records 汇总。
    final periodBooks = records.where((r) => r.readTime > 0).toList();
    final totalBooks = filteredDaily.isEmpty && period != ReadPeriod.all
        ? 0
        : periodBooks.length;

    var readingBooksCount = 0;
    var finishedBooksCount = 0;

    if (totalBooks > 0) {
      for (final r in periodBooks) {
        final shelfBook = shelfMap[r.bookName];
        if (shelfBook != null) {
          readingBooksCount++;
          // 判断是否已读完：durChapterIndex >= totalChapterNum - 1 且 totalChapterNum > 0
          if (shelfBook.totalChapterNum > 0 &&
              shelfBook.durChapterIndex >= shelfBook.totalChapterNum - 1) {
            finishedBooksCount++;
          }
        }
      }
    }

    // 前10本书籍排行
    final sortedRecords = [...periodBooks]
      ..sort((a, b) => b.readTime.compareTo(a.readTime));
    final topBooks = sortedRecords.take(10).map((r) {
      final shelfBook = shelfMap[r.bookName];
      return ReadBookRanking(
        bookName: r.bookName,
        author: shelfBook?.author ?? '',
        readTimeMs: r.readTime,
        coverUrl: shelfBook?.coverUrl,
      );
    }).toList();

    // 3. dailyTopBook（日期 -> 当日阅读最长的一本书）
    final dailyTopBook = <String, ({String bookName, String author, String? coverUrl})>{};
    if (topBooks.isNotEmpty) {
      final top1 = topBooks.first;
      for (final dateStr in dailyRecords.keys) {
        if ((dailyRecords[dateStr] ?? 0) > 0) {
          dailyTopBook[dateStr] = (
            bookName: top1.bookName,
            author: top1.author,
            coverUrl: top1.coverUrl,
          );
        }
      }
    }

    // 4. dailyTimeData 柱状图生成
    final dailyTimeData = <({DateTime date, int seconds})>[];
    if (period == ReadPeriod.all) {
      // all 为空
    } else if (period == ReadPeriod.year) {
      // 年模式：12个月汇总
      for (var month = 1; month <= 12; month++) {
        final monthStart = DateTime(refDate.year, month, 1);
        final nextMonthStart = month == 12
            ? DateTime(refDate.year + 1, 1, 1)
            : DateTime(refDate.year, month + 1, 1);
        var monthSeconds = 0;
        for (final entry in filteredDaily.entries) {
          final d = _parseIsoDate(entry.key);
          if (d != null &&
              !d.isBefore(monthStart) &&
              d.isBefore(nextMonthStart)) {
            monthSeconds += entry.value;
          }
        }
        dailyTimeData.add((date: monthStart, seconds: monthSeconds));
      }
    } else {
      // day / week / month 模式：按天切片
      var curr = startDate;
      while (!curr.isAfter(endDate)) {
        final dateKey = _formatIsoDate(curr);
        final sec = filteredDaily[dateKey] ?? 0;
        dailyTimeData.add((date: curr, seconds: sec));
        curr = curr.add(const Duration(days: 1));
      }
    }

    // 5. allDailyTimes 与 allDailyCounts（热力图）
    final allDailyTimes = <String, int>{};
    final allDailyCounts = <String, int>{};
    for (final entry in dailyRecords.entries) {
      if (entry.value > 0) {
        allDailyTimes[entry.key] = entry.value;
        allDailyCounts[entry.key] = 1; // 当日阅读本数
      }
    }

    return ReadRecordOverviewState(
      period: period,
      referenceDate: refDate,
      totalTimeMs: totalTimeMs,
      readingDays: readingDays,
      totalBooks: totalBooks,
      finishedBooks: finishedBooksCount,
      readingBooks: readingBooksCount,
      dailyTimeData: dailyTimeData,
      topBooks: topBooks,
      dailyTopBook: dailyTopBook,
      allDailyTimes: allDailyTimes,
      allDailyCounts: allDailyCounts,
    );
  }

  /// 获取周期起止日期范围
  static (DateTime, DateTime) getPeriodRange(
    ReadPeriod period,
    DateTime refDate,
  ) {
    final base = DateTime(refDate.year, refDate.month, refDate.day);
    switch (period) {
      case ReadPeriod.day:
        return (base, base);
      case ReadPeriod.week:
        // DateTime.weekday: 1 (Monday) ~ 7 (Sunday)
        final start = base.subtract(Duration(days: base.weekday - 1));
        final end = base.add(Duration(days: 7 - base.weekday));
        return (start, end);
      case ReadPeriod.month:
        final start = DateTime(base.year, base.month, 1);
        // 下个月第1天减1天即为当月最后一天
        final nextMonth = base.month == 12
            ? DateTime(base.year + 1, 1, 1)
            : DateTime(base.year, base.month + 1, 1);
        final end = nextMonth.subtract(const Duration(days: 1));
        return (start, end);
      case ReadPeriod.year:
        final start = DateTime(base.year, 1, 1);
        final end = DateTime(base.year, 12, 31);
        return (start, end);
      case ReadPeriod.all:
        return (DateTime(1970, 1, 1), DateTime(2099, 12, 31));
    }
  }

  static DateTime? _parseIsoDate(String str) {
    try {
      final parts = str.split('-');
      if (parts.length != 3) return null;
      return DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    } catch (_) {
      return null;
    }
  }

  static String _formatIsoDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

/// 阅读总览 Provider
final readRecordOverviewNotifierProvider =
    NotifierProvider<ReadRecordOverviewNotifier, ReadRecordOverviewState>(
  ReadRecordOverviewNotifier.new,
);
