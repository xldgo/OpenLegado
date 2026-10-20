import 'package:flutter/foundation.dart';

/// 阅读统计时间周期（对齐上游 ReadPeriod）
enum ReadPeriod { day, week, month, year, all }

/// 书籍阅读排行项（对齐上游 ReadBookRanking）
@immutable
class ReadBookRanking {
  final String bookName;
  final String author;
  final int readTimeMs;
  final String? coverUrl;

  const ReadBookRanking({
    required this.bookName,
    required this.author,
    required this.readTimeMs,
    this.coverUrl,
  });

  ReadBookRanking copyWith({
    String? bookName,
    String? author,
    int? readTimeMs,
    String? coverUrl,
  }) {
    return ReadBookRanking(
      bookName: bookName ?? this.bookName,
      author: author ?? this.author,
      readTimeMs: readTimeMs ?? this.readTimeMs,
      coverUrl: coverUrl ?? this.coverUrl,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReadBookRanking &&
          runtimeType == other.runtimeType &&
          bookName == other.bookName &&
          author == other.author &&
          readTimeMs == other.readTimeMs &&
          coverUrl == other.coverUrl;

  @override
  int get hashCode => Object.hash(bookName, author, readTimeMs, coverUrl);

  @override
  String toString() =>
      'ReadBookRanking(bookName: $bookName, author: $author, readTimeMs: $readTimeMs, coverUrl: $coverUrl)';
}

/// 阅读总览页面状态（对齐上游 ReadRecordOverviewUiState）
@immutable
class ReadRecordOverviewState {
  /// 当前统计周期
  final ReadPeriod period;

  /// 参考基准日期
  final DateTime referenceDate;

  /// 总阅读毫秒数
  final int totalTimeMs;

  /// 阅读天数
  final int readingDays;

  /// 本周期读过书籍数
  final int totalBooks;

  /// 本周读书架中已读完书籍数
  final int finishedBooks;

  /// 本周期内在读书籍数
  final int readingBooks;

  /// 柱状图数据源（日内每小时/周内每天/月内每天/年内每月/总为空）
  final List<({DateTime date, int seconds})> dailyTimeData;

  /// 按本周期阅读时长降序排序的前10本
  final List<ReadBookRanking> topBooks;

  /// 日期 YYYY-MM-DD -> 当日阅读时长最长的一本书（用于读书日历）
  final Map<String, ({String bookName, String author, String? coverUrl})>
  dailyTopBook;

  /// 日期 YYYY-MM-DD -> 当日阅读秒数（用于热力图）
  final Map<String, int> allDailyTimes;

  /// 日期 YYYY-MM-DD -> 当日阅读本数（用于热力图）
  final Map<String, int> allDailyCounts;

  /// 加载中
  final bool isLoading;

  final String? error;

  const ReadRecordOverviewState({
    this.period = ReadPeriod.day,
    required this.referenceDate,
    this.totalTimeMs = 0,
    this.readingDays = 0,
    this.totalBooks = 0,
    this.finishedBooks = 0,
    this.readingBooks = 0,
    this.dailyTimeData = const [],
    this.topBooks = const [],
    this.dailyTopBook = const {},
    this.allDailyTimes = const {},
    this.allDailyCounts = const {},
    this.isLoading = false,
    this.error,
  });

  ReadRecordOverviewState copyWith({
    ReadPeriod? period,
    DateTime? referenceDate,
    int? totalTimeMs,
    int? readingDays,
    int? totalBooks,
    int? finishedBooks,
    int? readingBooks,
    List<({DateTime date, int seconds})>? dailyTimeData,
    List<ReadBookRanking>? topBooks,
    Map<String, ({String bookName, String author, String? coverUrl})>?
    dailyTopBook,
    Map<String, int>? allDailyTimes,
    Map<String, int>? allDailyCounts,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return ReadRecordOverviewState(
      period: period ?? this.period,
      referenceDate: referenceDate ?? this.referenceDate,
      totalTimeMs: totalTimeMs ?? this.totalTimeMs,
      readingDays: readingDays ?? this.readingDays,
      totalBooks: totalBooks ?? this.totalBooks,
      finishedBooks: finishedBooks ?? this.finishedBooks,
      readingBooks: readingBooks ?? this.readingBooks,
      dailyTimeData: dailyTimeData ?? this.dailyTimeData,
      topBooks: topBooks ?? this.topBooks,
      dailyTopBook: dailyTopBook ?? this.dailyTopBook,
      allDailyTimes: allDailyTimes ?? this.allDailyTimes,
      allDailyCounts: allDailyCounts ?? this.allDailyCounts,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
