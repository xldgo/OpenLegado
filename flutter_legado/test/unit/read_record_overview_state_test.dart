import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_legado/src/features/read_records/read_records.dart';
import 'package:flutter_legado/src/features/bookshelf/bookshelf.dart';
import 'package:flutter_legado/src/data/repositories/mock_read_record_repository.dart';
import 'package:flutter_legado/src/models/models.dart';

class AuditRepo extends MockReadRecordRepository {
  List<ReadRecordDetail> data = [];
  final pending = <Completer<List<ReadRecordDetail>>>[];
  int calls = 0;
  @override
  Future<List<ReadRecordDetail>> getAllReadRecordDetails() async {
    calls++;
    if (pending.isNotEmpty) return pending.removeAt(0).future;
    return List.from(data);
  }
}

class AuditShelf extends BookshelfNotifier {
  @override
  BookshelfState build() => const BookshelfState();
}

class FixedOverview extends ReadRecordOverviewNotifier {
  final DateTime date;
  final ReadPeriod period;
  FixedOverview(this.date, this.period);
  @override
  ReadRecordOverviewState build() =>
      ReadRecordOverviewState(referenceDate: date, period: period);
}

Future<void> flush() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

ProviderContainer containerFor(
  MockReadRecordRepository repo, {
  DateTime? date,
  ReadPeriod period = ReadPeriod.day,
}) => ProviderContainer(
  overrides: [
    readRecordRepositoryProvider.overrideWithValue(repo),
    bookshelfNotifierProvider.overrideWith(AuditShelf.new),
    if (date != null)
      readRecordOverviewNotifierProvider.overrideWith(
        () => FixedOverview(date, period),
      ),
  ],
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('月末与闰年步进使用有效日期', () {
    final c = containerFor(
      AuditRepo(),
      date: DateTime(2026, 3, 31),
      period: ReadPeriod.month,
    );
    addTearDown(c.dispose);
    c.read(readRecordOverviewNotifierProvider.notifier).previousPeriod();
    expect(
      c.read(readRecordOverviewNotifierProvider).referenceDate,
      DateTime(2026, 2, 28),
    );
    final leap = containerFor(
      AuditRepo(),
      date: DateTime(2024, 2, 29),
      period: ReadPeriod.year,
    );
    addTearDown(leap.dispose);
    leap.read(readRecordOverviewNotifierProvider.notifier).nextPeriod();
    expect(
      leap.read(readRecordOverviewNotifierProvider).referenceDate,
      DateTime(2025, 2, 28),
    );
  });
  test('强制刷新重新查询同年时长', () async {
    final repo = AuditRepo()
      ..data = [
        const ReadRecordDetail(
          bookName: '甲',
          author: '甲',
          date: '2026-01-01',
          readTime: 60000,
        ),
      ];
    final c = containerFor(repo, date: DateTime(2026, 1, 1));
    addTearDown(c.dispose);
    final n = c.read(readRecordOverviewNotifierProvider.notifier);
    await n.refresh();
    expect(c.read(readRecordOverviewNotifierProvider).totalTimeMs, 60000);
    repo.data = [
      const ReadRecordDetail(
        bookName: '甲',
        author: '甲',
        date: '2026-01-01',
        readTime: 120000,
      ),
    ];
    await n.refresh();
    expect(c.read(readRecordOverviewNotifierProvider).totalTimeMs, 120000);
  });
  test('搜索不影响总览总时长', () async {
    final repo = MockReadRecordRepository();
    await repo.putReadRecord(const ReadRecord(bookName: '甲', readTime: 60000));
    await repo.putReadRecord(const ReadRecord(bookName: '乙', readTime: 120000));
    final c = containerFor(repo);
    addTearDown(c.dispose);
    final sub = c.listen(readRecordOverviewNotifierProvider, (_, _) {});
    addTearDown(sub.close);
    await c.read(readRecordNotifierProvider.notifier).load();
    await c.read(readRecordOverviewNotifierProvider.notifier).refresh();
    c
        .read(readRecordOverviewNotifierProvider.notifier)
        .setPeriod(ReadPeriod.all);
    expect(c.read(readRecordOverviewNotifierProvider).totalTimeMs, 180000);
    c.read(readRecordNotifierProvider.notifier).setSearchQuery('甲');
    expect(c.read(readRecordOverviewNotifierProvider).totalTimeMs, 180000);
  });
  test('请求中跨年导航使用当前选择与完整明细', () async {
    final completer = Completer<List<ReadRecordDetail>>();
    final repo = AuditRepo()..pending.add(completer);
    final c = containerFor(repo, date: DateTime(2025, 12, 31));
    addTearDown(c.dispose);
    final n = c.read(readRecordOverviewNotifierProvider.notifier);
    final f = n.refresh();
    n.nextPeriod();
    completer.complete([
      const ReadRecordDetail(
        bookName: '甲',
        author: '甲',
        date: '2026-01-01',
        readTime: 120000,
      ),
    ]);
    await f;
    expect(
      c.read(readRecordOverviewNotifierProvider).referenceDate,
      DateTime(2026, 1, 1),
    );
    expect(c.read(readRecordOverviewNotifierProvider).totalTimeMs, 120000);
  });
  test('重叠刷新旧请求不覆盖新请求', () async {
    final old = Completer<List<ReadRecordDetail>>(),
        latest = Completer<List<ReadRecordDetail>>();
    final repo = AuditRepo()..pending.addAll([old, latest]);
    final c = containerFor(repo, date: DateTime(2026, 1, 1));
    addTearDown(c.dispose);
    final n = c.read(readRecordOverviewNotifierProvider.notifier);
    final a = n.refresh();
    final b = n.refresh();
    latest.complete([
      const ReadRecordDetail(
        bookName: '乙',
        author: '乙',
        date: '2026-01-01',
        readTime: 120000,
      ),
    ]);
    await b;
    old.complete([
      const ReadRecordDetail(
        bookName: '甲',
        author: '甲',
        date: '2026-01-01',
        readTime: 60000,
      ),
    ]);
    await a;
    expect(c.read(readRecordOverviewNotifierProvider).totalTimeMs, 120000);
  });
  test('保存、删除与清空成功后自动刷新', () async {
    final repo = MockReadRecordRepository();
    final c = containerFor(repo);
    addTearDown(c.dispose);
    final sub = c.listen(readRecordOverviewNotifierProvider, (_, _) {});
    addTearDown(sub.close);
    await flush();
    final n = c.read(readRecordOverviewNotifierProvider.notifier);
    n.setPeriod(ReadPeriod.all);
    await repo.putReadRecord(
      const ReadRecord(bookName: '甲', author: '甲', readTime: 1500),
    );
    await flush();
    expect(c.read(readRecordOverviewNotifierProvider).totalTimeMs, 1500);
    expect(c.read(readRecordOverviewNotifierProvider).totalBooks, 1);
    await repo.deleteReadRecord('甲');
    await flush();
    expect(c.read(readRecordOverviewNotifierProvider).dailyTopBook, isEmpty);
    await repo.putReadRecord(const ReadRecord(bookName: '乙', readTime: 2000));
    await flush();
    await repo.clearReadRecords();
    await flush();
    expect(c.read(readRecordOverviewNotifierProvider).allDailyTimes, isEmpty);
  });
  test('Repository 替换与卸载忽略旧请求', () async {
    final pending = Completer<List<ReadRecordDetail>>();
    final first = AuditRepo()..pending.add(pending);
    final c = containerFor(first);
    final sub = c.listen(readRecordOverviewNotifierProvider, (_, _) {});
    await flush();
    final second = AuditRepo()
      ..data = [
        ReadRecordDetail(
          bookName: '乙',
          author: '乙',
          date:
              '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}',
          readTime: 2000,
        ),
      ];
    c.updateOverrides([
      readRecordRepositoryProvider.overrideWithValue(second),
      bookshelfNotifierProvider.overrideWith(AuditShelf.new),
    ]);
    await flush();
    expect(c.read(readRecordOverviewNotifierProvider).totalTimeMs, 2000);
    pending.complete([]);
    await flush();
    expect(c.read(readRecordOverviewNotifierProvider).totalTimeMs, 2000);
    sub.close();
    c.dispose();
    final end = Completer<List<ReadRecordDetail>>();
    final disposed = containerFor(
      AuditRepo()..pending.add(end),
      date: DateTime(2026, 1, 1),
    );
    final f = disposed
        .read(readRecordOverviewNotifierProvider.notifier)
        .refresh();
    disposed.dispose();
    end.complete([]);
    await f;
  });
  test('日分布订阅真实会话并随新增删除及刷新更新，切换日期重新分桶', () async {
    final repo = MockReadRecordRepository();
    final c = containerFor(repo);
    addTearDown(c.dispose);
    final sub = c.listen(readRecordOverviewNotifierProvider, (_, _) {});
    addTearDown(sub.close);
    await flush();
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day, 10, 15);
    await repo.putReadRecord(
      ReadRecord(
        bookName: '小时书',
        author: '甲',
        readTime: 1800000,
        lastRead: end.millisecondsSinceEpoch,
      ),
    );
    await flush();
    final n = c.read(readRecordOverviewNotifierProvider.notifier);
    expect(
      c.read(readRecordOverviewNotifierProvider).dailyTimeData[9].seconds,
      900,
    );
    expect(
      c.read(readRecordOverviewNotifierProvider).dailyTimeData[10].seconds,
      900,
    );
    n.previousPeriod();
    expect(
      c
          .read(readRecordOverviewNotifierProvider)
          .dailyTimeData
          .every((e) => e.seconds == 0),
      isTrue,
    );
    n.nextPeriod();
    expect(
      c.read(readRecordOverviewNotifierProvider).dailyTimeData[10].seconds,
      900,
    );
    await n.refresh();
    expect(
      c.read(readRecordOverviewNotifierProvider).dailyTimeData[9].seconds,
      900,
    );
    await repo.deleteReadRecord('小时书');
    await flush();
    expect(
      c
          .read(readRecordOverviewNotifierProvider)
          .dailyTimeData
          .every((e) => e.seconds == 0),
      isTrue,
    );
  });

  test('首页日历和排行不跟随总览周期选择', () async {
    final c = containerFor(MockReadRecordRepository());
    addTearDown(c.dispose);
    final sub = c.listen(homeReadRecordOverviewProvider, (_, _) {});
    addTearDown(sub.close);
    await flush();
    final n = c.read(readRecordOverviewNotifierProvider.notifier);
    n.setPeriod(ReadPeriod.year);
    n.previousPeriod();
    expect(
      c.read(homeReadRecordOverviewProvider).referenceDate.year,
      DateTime.now().year,
    );
  });
}
