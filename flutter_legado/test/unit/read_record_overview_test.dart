import 'package:flutter_legado/src/features/read_records/read_record_overview_calculator.dart';
import 'package:flutter_legado/src/features/read_records/read_records.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ReadRecordSession session(int id, DateTime start, DateTime end) =>
      ReadRecordSession(
        id: id,
        bookName: '甲',
        author: '作者',
        startTime: start.millisecondsSinceEpoch,
        endTime: end.millisecondsSinceEpoch,
      );
  test('真实会话按小时求交集，不借日累计量补造分布', () {
    final day = DateTime(2026, 5, 20);
    final data = ReadRecordOverviewCalculator.hourlyDistribution(day, [
      session(1, DateTime(2026, 5, 19, 23, 45), DateTime(2026, 5, 20, 0, 15)),
      session(2, DateTime(2026, 5, 20, 8, 45), DateTime(2026, 5, 20, 10, 15)),
      session(3, DateTime(2026, 5, 20, 23, 50), DateTime(2026, 5, 21, 0, 20)),
    ]);
    expect(data.length, 24);
    expect(
      [
        data[0].seconds,
        data[8].seconds,
        data[9].seconds,
        data[10].seconds,
        data[23].seconds,
      ],
      [900, 900, 3600, 900, 600],
    );
    expect(
      ReadRecordOverviewCalculator.hourlyDistribution(
        day,
        [],
      ).every((h) => h.seconds == 0),
      isTrue,
    );
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
}
