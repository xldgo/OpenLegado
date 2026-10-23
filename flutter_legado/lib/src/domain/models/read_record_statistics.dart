/// 阅读统计时间周期（对齐上游 ReadPeriod）
enum ReadPeriod { day, week, month, year, all }

/// 书籍阅读排行项（对齐上游 ReadBookRanking）
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

/// Rust查询的统计数据；不包含页面加载状态和周期选择。— Codex + UI
final class ReadRecordStatistics {
  const ReadRecordStatistics({
    this.totalTimeMs = 0,
    this.readingDays = 0,
    this.totalBooks = 0,
    this.finishedBooks = 0,
    this.readingBooks = 0,
    this.topBooks = const [],
    this.dailyTimeData = const [],
    this.dailyTopBook = const {},
    this.allDailyTimes = const {},
    this.allDailyCounts = const {},
  });
  final int totalTimeMs, readingDays, totalBooks, finishedBooks, readingBooks;
  final List<ReadBookRanking> topBooks;
  final List<({DateTime date, int seconds})> dailyTimeData;
  final Map<String, ({String bookName, String author, String? coverUrl})>
  dailyTopBook;
  final Map<String, int> allDailyTimes, allDailyCounts;
}
