import 'package:flutter_legado/src/features/read_records/read_record_overview_calculator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/features/read_records/read_records.dart';
import 'package:flutter_legado/src/models/models.dart';

void main() {
  ReadRecordSession session(int id, DateTime start, DateTime end) =>
      ReadRecordSession(
        id: id,
        bookName: '甲',
        author: '作者',
        startTime: start.millisecondsSinceEpoch,
        endTime: end.millisecondsSinceEpoch,
      );
  test('日分布为24个小时，跨小时及午夜只计区间交集', () {
    final state = ReadRecordOverviewNotifier.computeOverview(
      period: ReadPeriod.day,
      referenceDate: DateTime(2026, 5, 20),
      details: [],
      records: [],
      shelfBooks: [],
      sessions: [
        session(1, DateTime(2026, 5, 19, 23, 45), DateTime(2026, 5, 20, 0, 15)),
        session(2, DateTime(2026, 5, 20, 8, 45), DateTime(2026, 5, 20, 10, 15)),
        session(3, DateTime(2026, 5, 20, 23, 50), DateTime(2026, 5, 21, 0, 20)),
        session(4, DateTime(2026, 5, 21, 1), DateTime(2026, 5, 21, 2)),
      ],
    );
    final data = state.dailyTimeData;
    expect(data.length, 24);
    expect(data.map((e) => e.date.hour), List.generate(24, (i) => i));
    expect(data[0].seconds, 900);
    expect(data[8].seconds, 900);
    expect(data[9].seconds, 3600);
    expect(data[10].seconds, 900);
    expect(data[23].seconds, 600);
    expect(data.fold<int>(0, (sum, e) => sum + e.seconds), 6900);
  });
  test('小时汇总先合并毫秒再取秒，忽略倒序和空会话，小时边界不重复', () {
    final start = DateTime(2026, 5, 20, 9);
    final data = ReadRecordOverviewCalculator.hourlyDistribution(start, [
      session(1, start, start.add(const Duration(milliseconds: 600))),
      session(
        2,
        start.add(const Duration(seconds: 1)),
        start.add(const Duration(milliseconds: 1600)),
      ),
      session(3, start, start),
      session(4, start.add(const Duration(hours: 1)), start),
      session(5, DateTime(2026, 5, 20, 8, 59), start),
    ]);
    expect(data[8].seconds, 60);
    expect(data[9].seconds, 1);
    expect(data[10].seconds, 0);
  });
  test('缺少会话时不以日累计或最后阅读时间伪造小时分布', () {
    final state = ReadRecordOverviewNotifier.computeOverview(
      period: ReadPeriod.day,
      referenceDate: DateTime(2026, 5, 20),
      details: const [
        ReadRecordDetail(
          bookName: '甲',
          author: '',
          date: '2026-05-20',
          readTime: 60000,
        ),
      ],
      records: [],
      shelfBooks: [],
    );
    expect(state.totalTimeMs, 60000);
    expect(state.dailyTimeData.length, 24);
    expect(state.dailyTimeData.every((e) => e.seconds == 0), isTrue);
  });
  group('周期范围', () {
    test('日', () {
      expect(
        ReadRecordOverviewNotifier.getPeriodRange(
          ReadPeriod.day,
          DateTime(2026, 5, 20),
        ),
        (DateTime(2026, 5, 20), DateTime(2026, 5, 20)),
      );
    });
    test('周', () {
      expect(
        ReadRecordOverviewNotifier.getPeriodRange(
          ReadPeriod.week,
          DateTime(2026, 5, 20),
        ),
        (DateTime(2026, 5, 18), DateTime(2026, 5, 24)),
      );
    });
    test('月与闰年', () {
      expect(
        ReadRecordOverviewNotifier.getPeriodRange(
          ReadPeriod.month,
          DateTime(2024, 2, 20),
        ),
        (DateTime(2024, 2, 1), DateTime(2024, 2, 29)),
      );
    });
    test('年', () {
      expect(
        ReadRecordOverviewNotifier.getPeriodRange(
          ReadPeriod.year,
          DateTime(2026, 5, 20),
        ),
        (DateTime(2026, 1, 1), DateTime(2026, 12, 31)),
      );
    });
    test('总', () {
      final (start, end) = ReadRecordOverviewNotifier.getPeriodRange(
        ReadPeriod.all,
        DateTime(2026, 5, 20),
      );
      expect(start.year, 1);
      expect(end.year, 9999);
    });
  });
  const records = [
    ReadRecord(bookName: '甲', author: '甲作者', readTime: 3600000),
    ReadRecord(bookName: '乙', author: '乙作者', readTime: 9000000),
    ReadRecord(bookName: '丙', author: '丙作者', readTime: 1800000),
  ];
  const details = [
    ReadRecordDetail(
      bookName: '甲',
      author: '甲作者',
      date: '2026-04-10',
      readTime: 3600000,
    ),
    ReadRecordDetail(
      bookName: '丙',
      author: '丙作者',
      date: '2026-05-18',
      readTime: 1800000,
    ),
    ReadRecordDetail(
      bookName: '乙',
      author: '乙作者',
      date: '2026-05-19',
      readTime: 3600000,
    ),
    ReadRecordDetail(
      bookName: '乙',
      author: '乙作者',
      date: '2026-05-20',
      readTime: 5400000,
    ),
  ];
  const books = [
    Book(
      name: '甲',
      author: '甲作者',
      totalChapterNum: 10,
      durChapterIndex: 9,
      durChapterPos: 1,
    ),
    Book(
      name: '乙',
      author: '乙作者',
      totalChapterNum: 10,
      durChapterIndex: 9,
      durChapterPos: 0,
    ),
  ];
  ReadRecordOverviewState compute(ReadPeriod period) =>
      ReadRecordOverviewNotifier.computeOverview(
        period: period,
        referenceDate: DateTime(2026, 5, 20),
        details: details,
        records: records,
        shelfBooks: books,
      );
  test('周排行只统计本周真实读过的书，日历按每日最长明细', () {
    final s = compute(ReadPeriod.week);
    expect(s.totalTimeMs, 10800000);
    expect(s.readingDays, 3);
    expect(s.totalBooks, 2);
    expect(s.readingBooks, 2);
    expect(s.finishedBooks, 0);
    expect(s.topBooks.map((r) => r.bookName), ['乙', '丙']);
    expect(s.topBooks.first.readTimeMs, 9000000);
    expect(s.dailyTopBook['2026-05-18']!.bookName, '丙');
    expect(s.dailyTimeData.length, 7);
  });
  test('月时长与天数', () {
    final s = compute(ReadPeriod.month);
    expect(s.totalTimeMs, 10800000);
    expect(s.readingDays, 3);
    expect(s.dailyTimeData.length, 31);
  });
  test('年按12个月汇总', () {
    final s = compute(ReadPeriod.year);
    expect(s.totalTimeMs, 14400000);
    expect(s.dailyTimeData.length, 12);
    expect(s.dailyTimeData[3].seconds, 3600);
    expect(s.dailyTimeData[4].seconds, 10800);
  });
  test('总时长来自未过滤累计数据，书籍与天数来自全量明细', () {
    final s = compute(ReadPeriod.all);
    expect(s.totalTimeMs, 14400000);
    expect(s.readingDays, 4);
    expect(s.totalBooks, 3);
    expect(s.finishedBooks, 1);
    expect(s.dailyTimeData, isEmpty);
  });
  test('无明细的周期没有排行，不从累计记录推算', () {
    final s = ReadRecordOverviewNotifier.computeOverview(
      period: ReadPeriod.week,
      referenceDate: DateTime(2026, 1, 1),
      details: [],
      records: records,
      shelfBooks: books,
    );
    expect(s.totalTimeMs, 0);
    expect(s.totalBooks, 0);
    expect(s.topBooks, isEmpty);
    expect(s.dailyTopBook, isEmpty);
    expect(s.dailyTimeData.length, 7);
  });
  test('同名作者、跨设备合并、本数和封面均按真实身份', () {
    final s = ReadRecordOverviewNotifier.computeOverview(
      period: ReadPeriod.day,
      referenceDate: DateTime(2026, 1, 1),
      details: const [
        ReadRecordDetail(
          bookName: '同名',
          author: '甲',
          date: '2026-01-01',
          readTime: 400,
        ),
        ReadRecordDetail(
          bookName: '同名',
          author: '甲',
          date: '2026-01-01',
          readTime: 600,
        ),
        ReadRecordDetail(
          bookName: '同名',
          author: '乙',
          date: '2026-01-01',
          readTime: 1500,
        ),
      ],
      records: const [
        ReadRecord(
          bookName: '同名',
          author: '\u001eauthors:["甲","乙"]',
          readTime: 2500,
        ),
      ],
      shelfBooks: const [Book(name: '同名', author: '乙', coverUrl: '乙封面')],
    );
    expect(s.totalTimeMs, 2500);
    expect(s.totalBooks, 2);
    expect(s.readingBooks, 2);
    expect(s.allDailyCounts['2026-01-01'], 2);
    expect(s.allDailyTimes['2026-01-01'], 2);
    expect(s.dailyTopBook['2026-01-01']!.author, '乙');
    expect(s.topBooks.first.coverUrl, '乙封面');
  });
  test('跨年周包含两年的真实明细，不接受归一化的无效日期', () {
    final s = ReadRecordOverviewNotifier.computeOverview(
      period: ReadPeriod.week,
      referenceDate: DateTime(2026, 1, 1),
      details: const [
        ReadRecordDetail(
          bookName: '甲',
          author: '甲',
          date: '2025-12-29',
          readTime: 60000,
        ),
        ReadRecordDetail(
          bookName: '甲',
          author: '甲',
          date: '2026-01-01',
          readTime: 120000,
        ),
        ReadRecordDetail(
          bookName: '假',
          author: '甲',
          date: '2026-02-31',
          readTime: 100000,
        ),
      ],
      records: [],
      shelfBooks: [],
    );
    expect(s.totalTimeMs, 180000);
    expect(s.readingDays, 2);
    expect(s.dailyTopBook, isNot(contains('2026-02-31')));
  });

  test('同日时长相同的日历封面按上游选择最后阅读的书', () {
    final state = ReadRecordOverviewNotifier.computeOverview(
      period: ReadPeriod.day,
      referenceDate: DateTime(2026, 1, 1),
      details: const [
        ReadRecordDetail(
          bookName: '甲',
          author: '甲',
          date: '2026-01-01',
          readTime: 1000,
          lastRead: 1,
        ),
        ReadRecordDetail(
          bookName: '乙',
          author: '乙',
          date: '2026-01-01',
          readTime: 1000,
          lastRead: 2,
        ),
      ],
      records: [],
      shelfBooks: [],
    );
    expect(state.dailyTopBook['2026-01-01']!.bookName, '乙');
  });
  test('当天明细合并跨设备同书、区分作者，保留前十以外书籍', () {
    final result = ReadRecordOverviewCalculator.booksForDay(
      date: DateTime(2026, 10, 13),
      details: [
        const ReadRecordDetail(
          bookName: '同名',
          author: '甲',
          date: '2026-10-13',
          readTime: 1000,
        ),
        const ReadRecordDetail(
          bookName: '同名',
          author: '甲',
          date: '2026-10-13',
          readTime: 2000,
        ),
        const ReadRecordDetail(
          bookName: '同名',
          author: '乙',
          date: '2026-10-13',
          readTime: 4000,
        ),
        const ReadRecordDetail(
          bookName: '其他日期',
          author: '甲',
          date: '2026-10-12',
          readTime: 5000,
        ),
        const ReadRecordDetail(
          bookName: '零时长',
          author: '甲',
          date: '2026-10-13',
          readTime: 0,
        ),
        for (var i = 0; i < 10; i++)
          ReadRecordDetail(
            bookName: '书$i',
            author: '甲',
            date: '2026-10-13',
            readTime: 100,
          ),
      ],
      shelfBooks: [],
    );
    expect(result.length, 12);
    expect(result[0].author, '乙');
    expect(result[0].readTimeMs, 4000);
    expect(result[1].author, '甲');
    expect(result[1].readTimeMs, 3000);
    expect(result.any((book) => book.bookName == '其他日期'), isFalse);
    expect(
      ReadRecordOverviewCalculator.booksForDay(
        date: DateTime(2026, 10, 14),
        details: [],
        shelfBooks: [],
      ),
      isEmpty,
    );
  });
}
