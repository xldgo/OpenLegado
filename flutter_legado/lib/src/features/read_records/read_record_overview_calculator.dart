import '../../models/read_record_identity.dart';
import 'read_record_overview_state.dart';

/// 统计页面的日历导航与平台小时边界；聚合由Rust负责。— Codex + UI
class ReadRecordOverviewCalculator {
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

  /// 使用平台本地日历生成边界，保留夏令时的跳时和重复小时。
  static List<DateTime> hourBoundaries(DateTime date) => List.generate(
    25,
    (hour) => DateTime(date.year, date.month, date.day, hour),
  );
}
