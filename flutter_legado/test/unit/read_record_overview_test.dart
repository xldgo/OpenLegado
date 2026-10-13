import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/features/read_records/read_records.dart';
import 'package:flutter_legado/src/models/models.dart';

void main() {
  group('ReadRecordOverview - getPeriodRange 时间切片', () {
    test('day 模式：起止时间均为当天', () {
      final refDate = DateTime(2026, 5, 20);
      final (start, end) = ReadRecordOverviewNotifier.getPeriodRange(
        ReadPeriod.day,
        refDate,
      );
      expect(start, DateTime(2026, 5, 20));
      expect(end, DateTime(2026, 5, 20));
    });

    test('week 模式：周一到周日（2026-05-20 为周三）', () {
      final refDate = DateTime(2026, 5, 20); // 星期三 (weekday=3)
      final (start, end) = ReadRecordOverviewNotifier.getPeriodRange(
        ReadPeriod.week,
        refDate,
      );
      expect(start, DateTime(2026, 5, 18)); // 周一
      expect(end, DateTime(2026, 5, 24)); // 周日
    });

    test('month 模式：当月1号到当月最后一天（平年2月与大月5月）', () {
      final feb = DateTime(2026, 2, 10);
      final (febStart, febEnd) = ReadRecordOverviewNotifier.getPeriodRange(
        ReadPeriod.month,
        feb,
      );
      expect(febStart, DateTime(2026, 2, 1));
      expect(febEnd, DateTime(2026, 2, 28));

      final may = DateTime(2026, 5, 15);
      final (mayStart, mayEnd) = ReadRecordOverviewNotifier.getPeriodRange(
        ReadPeriod.month,
        may,
      );
      expect(mayStart, DateTime(2026, 5, 1));
      expect(mayEnd, DateTime(2026, 5, 31));

      final dec = DateTime(2026, 12, 15);
      final (decStart, decEnd) = ReadRecordOverviewNotifier.getPeriodRange(
        ReadPeriod.month,
        dec,
      );
      expect(decStart, DateTime(2026, 12, 1));
      expect(decEnd, DateTime(2026, 12, 31));
    });

    test('year 模式：当年1月1日到当年12月31日', () {
      final refDate = DateTime(2026, 8, 15);
      final (start, end) = ReadRecordOverviewNotifier.getPeriodRange(
        ReadPeriod.year,
        refDate,
      );
      expect(start, DateTime(2026, 1, 1));
      expect(end, DateTime(2026, 12, 31));
    });

    test('all 模式：覆盖全时间范围', () {
      final refDate = DateTime(2026, 5, 20);
      final (start, end) = ReadRecordOverviewNotifier.getPeriodRange(
        ReadPeriod.all,
        refDate,
      );
      expect(start.isBefore(DateTime(2000, 1, 1)), isTrue);
      expect(end.isAfter(DateTime(2050, 1, 1)), isTrue);
    });
  });

  group('ReadRecordOverview - computeOverview 统计与指标计算', () {
    final sampleBooks = [
      const Book(
        name: '三体',
        author: '刘慈欣',
        coverUrl: 'https://example.com/3body.jpg',
        totalChapterNum: 100,
        durChapterIndex: 99, // 已读完
      ),
      const Book(
        name: '雪中悍刀行',
        author: '烽火戏诸侯',
        coverUrl: 'https://example.com/xuezhong.jpg',
        totalChapterNum: 500,
        durChapterIndex: 200, // 在读
      ),
      const Book(
        name: '诡秘之主',
        author: '爱潜水的乌贼',
        coverUrl: 'https://example.com/guimi.jpg',
        totalChapterNum: 300,
        durChapterIndex: 50, // 在读
      ),
    ];

    final sampleRecords = [
      const ReadRecordShow(
        bookName: '三体',
        readTime: 3600000, // 1小时 (ms)
        lastRead: 1700000000,
      ),
      const ReadRecordShow(
        bookName: '雪中悍刀行',
        readTime: 7200000, // 2小时 (ms)
        lastRead: 1700001000,
      ),
      const ReadRecordShow(
        bookName: '诡秘之主',
        readTime: 1800000, // 0.5小时 (ms)
        lastRead: 1700002000,
      ),
    ];

    final sampleDaily = {
      '2026-05-18': 1800, // 周一 30分钟
      '2026-05-19': 3600, // 周二 60分钟
      '2026-05-20': 5400, // 周三 90分钟
      '2026-04-10': 3600, // 4月（不在5月内）
    };

    test('周模式指标与柱状图（7天切片）', () {
      final state = ReadRecordOverviewNotifier.computeOverview(
        period: ReadPeriod.week,
        referenceDate: DateTime(2026, 5, 20),
        dailyRecords: sampleDaily,
        records: sampleRecords,
        shelfBooks: sampleBooks,
      );

      // 周内 05-18(1800) + 05-19(3600) + 05-20(5400) = 10800秒 = 10,800,000毫秒
      expect(state.totalTimeMs, 10800000);
      expect(state.readingDays, 3);
      expect(state.totalBooks, 3);
      expect(state.finishedBooks, 1); // 三体已读完
      expect(state.readingBooks, 3); // 3本都在书架中
      expect(state.dailyTimeData.length, 7); // 一~日 共7天
      expect(state.dailyTimeData[0].seconds, 1800); // 周一
      expect(state.dailyTimeData[1].seconds, 3600); // 周二
      expect(state.dailyTimeData[2].seconds, 5400); // 周三
      expect(state.dailyTimeData[3].seconds, 0); // 周四无数据

      // TopBooks 排序：雪中(7200000) > 三体(3600000) > 诡秘(1800000)
      expect(state.topBooks.length, 3);
      expect(state.topBooks[0].bookName, '雪中悍刀行');
      expect(state.topBooks[0].readTimeMs, 7200000);
      expect(state.topBooks[1].bookName, '三体');
      expect(state.topBooks[2].bookName, '诡秘之主');

      // dailyTopBook
      expect(state.dailyTopBook['2026-05-18']?.bookName, '雪中悍刀行');
    });

    test('月模式指标与柱状图（当月天数切片）', () {
      final state = ReadRecordOverviewNotifier.computeOverview(
        period: ReadPeriod.month,
        referenceDate: DateTime(2026, 5, 20),
        dailyRecords: sampleDaily,
        records: sampleRecords,
        shelfBooks: sampleBooks,
      );

      expect(state.dailyTimeData.length, 31); // 5月共31天
      expect(state.readingDays, 3);
      expect(state.totalTimeMs, 10800000);
    });

    test('年模式指标与柱状图（12个月汇总）', () {
      final state = ReadRecordOverviewNotifier.computeOverview(
        period: ReadPeriod.year,
        referenceDate: DateTime(2026, 5, 20),
        dailyRecords: sampleDaily,
        records: sampleRecords,
        shelfBooks: sampleBooks,
      );

      expect(state.dailyTimeData.length, 12); // 12个月
      expect(state.readingDays, 4); // 包含4月的1天
      // 4月 3600秒，5月 10800秒
      expect(state.dailyTimeData[3].seconds, 3600); // 4月 (索引3)
      expect(state.dailyTimeData[4].seconds, 10800); // 5月 (索引4)
      expect(state.dailyTimeData[0].seconds, 0); // 1月
    });

    test('all 模式：dailyTimeData 为空，总时长直接使用 records 汇总', () {
      final state = ReadRecordOverviewNotifier.computeOverview(
        period: ReadPeriod.all,
        referenceDate: DateTime(2026, 5, 20),
        dailyRecords: sampleDaily,
        records: sampleRecords,
        shelfBooks: sampleBooks,
      );

      expect(state.dailyTimeData, isEmpty);
      // records 汇总: 3600000 + 7200000 + 1800000 = 12600000
      expect(state.totalTimeMs, 12600000);
      expect(state.readingDays, 4);
    });

    test('空数据处理：无记录时指标全为0，无异常', () {
      final state = ReadRecordOverviewNotifier.computeOverview(
        period: ReadPeriod.week,
        referenceDate: DateTime(2026, 5, 20),
        dailyRecords: {},
        records: [],
        shelfBooks: [],
      );

      expect(state.totalTimeMs, 0);
      expect(state.readingDays, 0);
      expect(state.totalBooks, 0);
      expect(state.finishedBooks, 0);
      expect(state.readingBooks, 0);
      expect(state.topBooks, isEmpty);
      expect(state.dailyTopBook, isEmpty);
      expect(state.allDailyTimes, isEmpty);
      expect(state.allDailyCounts, isEmpty);
      expect(state.dailyTimeData.length, 7);
      expect(state.dailyTimeData.every((item) => item.seconds == 0), isTrue);
    });
  });
}
