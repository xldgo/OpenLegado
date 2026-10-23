import 'package:flutter_legado/src/features/read_records/read_records.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
