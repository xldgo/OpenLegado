import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_legado/src/features/read_records/read_records.dart';
import 'package:flutter_legado/src/features/read_records/read_record_overview_calculator.dart';
import 'package:flutter_legado/src/domain/models/read_record_statistics.dart';
import 'package:flutter_legado/src/features/bookshelf/bookshelf.dart';
import 'package:flutter_legado/src/data/repositories/mock_read_record_repository.dart';

class AuditRepo extends MockReadRecordRepository {
  ReadRecordStatistics result = const ReadRecordStatistics(totalTimeMs: 60000);
  Future<ReadRecordStatistics> Function(ReadPeriod, DateTime)? loader;
  final queries = <(ReadPeriod, DateTime)>[];
  @override
  Future<ReadRecordStatistics> getReadRecordOverview(
    ReadPeriod period,
    DateTime date,
  ) {
    queries.add((period, date));
    return loader?.call(period, date) ?? Future.value(result);
  }
}

class AuditShelf extends BookshelfNotifier {
  @override
  BookshelfState build() => const BookshelfState();
}

Future<void> flush() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

ProviderContainer containerFor(AuditRepo repo) => ProviderContainer(
  overrides: [
    readRecordRepositoryProvider.overrideWithValue(repo),
    bookshelfNotifierProvider.overrideWith(AuditShelf.new),
  ],
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('月末及闰年日期步进不溢出', () {
    expect(
      ReadRecordOverviewCalculator.stepDate(
        ReadPeriod.month,
        DateTime(2026, 3, 31),
        -1,
      ),
      DateTime(2026, 2, 28),
    );
    expect(
      ReadRecordOverviewCalculator.stepDate(
        ReadPeriod.year,
        DateTime(2024, 2, 29),
        1,
      ),
      DateTime(2025, 2, 28),
    );
  });
  test('成功写入与强制刷新重新查询，查询失败展示且可恢复', () async {
    final repo = AuditRepo();
    final c = containerFor(repo);
    addTearDown(c.dispose);
    final sub = c.listen(readRecordOverviewNotifierProvider, (_, _) {});
    addTearDown(sub.close);
    await flush();
    expect(c.read(readRecordOverviewNotifierProvider).totalTimeMs, 60000);
    repo.result = const ReadRecordStatistics(totalTimeMs: 120000);
    await repo.clearReadRecords();
    await flush();
    expect(c.read(readRecordOverviewNotifierProvider).totalTimeMs, 120000);
    repo.loader = (_, _) => Future.error(StateError('统计查询失败'));
    await c.read(readRecordOverviewNotifierProvider.notifier).refresh();
    await flush();
    expect(
      c.read(readRecordOverviewNotifierProvider).error,
      contains('统计查询失败'),
    );
    repo.loader = null;
    repo.result = const ReadRecordStatistics(totalTimeMs: 180000);
    await c.read(readRecordOverviewNotifierProvider.notifier).refresh();
    await flush();
    expect(c.read(readRecordOverviewNotifierProvider).totalTimeMs, 180000);
    expect(c.read(readRecordOverviewNotifierProvider).error, isNull);
  });
  test('请求中导航与仓储替换后旧查询不能覆盖当前周期', () async {
    final pending = Completer<ReadRecordStatistics>();
    final repo = AuditRepo()
      ..loader = (period, date) => period == ReadPeriod.day
          ? pending.future
          : Future.value(const ReadRecordStatistics(totalTimeMs: 200));
    final c = containerFor(repo);
    addTearDown(c.dispose);
    final sub = c.listen(readRecordOverviewNotifierProvider, (_, _) {});
    addTearDown(sub.close);
    await flush();
    c
        .read(readRecordOverviewNotifierProvider.notifier)
        .setPeriod(ReadPeriod.year);
    await flush();
    expect(c.read(readRecordOverviewNotifierProvider).totalTimeMs, 200);
    final replacement = AuditRepo()
      ..result = const ReadRecordStatistics(totalTimeMs: 300);
    c.updateOverrides([
      readRecordRepositoryProvider.overrideWithValue(replacement),
      bookshelfNotifierProvider.overrideWith(AuditShelf.new),
    ]);
    await flush();
    pending.complete(const ReadRecordStatistics(totalTimeMs: 999));
    await flush();
    expect(c.read(readRecordOverviewNotifierProvider).period, ReadPeriod.year);
    expect(c.read(readRecordOverviewNotifierProvider).totalTimeMs, 300);
  });
  test('首页固定总查询，不跟随总览导航和记录搜索', () async {
    final repo = AuditRepo()
      ..loader = (period, date) => Future.value(
        ReadRecordStatistics(
          totalTimeMs: period == ReadPeriod.all ? 180000 : 60000,
        ),
      );
    final c = containerFor(repo);
    addTearDown(c.dispose);
    final home = c.listen(homeReadRecordOverviewProvider, (_, _) {});
    addTearDown(home.close);
    final overview = c.listen(readRecordOverviewNotifierProvider, (_, _) {});
    addTearDown(overview.close);
    await flush();
    final today = c.read(homeReadRecordOverviewProvider).referenceDate;
    c
        .read(readRecordOverviewNotifierProvider.notifier)
        .setPeriod(ReadPeriod.year);
    await flush();
    c.read(readRecordOverviewNotifierProvider.notifier).previousPeriod();
    await flush();
    c.read(readRecordNotifierProvider.notifier).setSearchQuery('其他书');
    await flush();
    expect(c.read(homeReadRecordOverviewProvider).referenceDate, today);
    expect(c.read(homeReadRecordOverviewProvider).totalTimeMs, 180000);
    expect(c.read(readRecordOverviewNotifierProvider).period, ReadPeriod.year);
    expect(
      repo.queries
          .where((q) => q.$1 == ReadPeriod.all)
          .every((q) => q.$2 == today),
      isTrue,
    );
  });
}
