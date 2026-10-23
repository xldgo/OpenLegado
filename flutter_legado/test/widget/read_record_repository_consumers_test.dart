import '../fixtures/app_test_api.dart';

import 'package:flutter_legado/src/domain/contracts/read_record_repository.dart';
import 'package:flutter_legado/src/features/read_records/read_records.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/features/home/presentation/home_tab_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_legado/src/domain/models/read_record_statistics.dart';
import 'package:flutter_legado/src/domain/models/read_record_list.dart';

import '../mocks/mocks.dart';

class _Records extends Mock implements ReadRecordRepository {}

void main() {
  late _Records records;
  late MockRustApi api;

  setUpAll(() {
    registerFallbacks();
    registerFallbackValue(DateTime(2026));
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    records = _Records();
    api = MockRustApi();
    when(() => api.bookshelfRepository.getBooks()).thenAnswer((_) async => []);
    when(() => api.bookGroupRepository.getBookGroups())
        .thenAnswer((_) async => []);
    when(() => records.getReadRecords()).thenAnswer(
      (_) async => [const ReadRecord(bookName: '窄接口小说', readTime: 5000)],
    );
    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final entry = ReadRecordBookEntry(
      bookName: '窄接口小说',
      author: '',
      date: date,
      durationMs: 7000,
      lastRead: 0,
    );
    when(() => records.getReadRecordList(any())).thenAnswer(
      (_) async => ReadRecordListData(
        aggregate: [entry],
        latest: [entry],
        totalTimeMs: 5000,
      ),
    );
    when(() => records.getReadRecordOverview(ReadPeriod.all, any())).thenAnswer(
      (_) async => ReadRecordStatistics(
        totalTimeMs: 5000,
        allDailyTimes: {date: 7},
        allDailyCounts: {date: 1},
      ),
    );
    when(() => records.getAllReadRecordDetails()).thenAnswer(
      (_) async => [
        ReadRecordDetail(
          bookName: '窄接口小说',
          author: '',
          date: date,
          readTime: 7000,
        ),
      ],
    );
    when(() => records.readRecordDailyList(now.year)).thenAnswer(
      (_) async => [
        {'date': date, 'seconds': 7},
      ],
    );
  });

  Future<void> pump(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: mergeTestOverrides([
          ...api.overrides,
          readRecordRepositoryProvider.overrideWithValue(records),
        ]),
        child: MaterialApp(home: page),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('记录页列表与摘要共用投影，不查询原始记录与明细', (tester) async {
    await pump(tester, const ReadRecordScreen());
    expect(find.text('窄接口小说'), findsOneWidget);
    verify(() => records.getReadRecordList('')).called(1);
    verifyNever(() => records.getReadRecords());
    verifyNever(() => records.getAllReadRecordDetails());
    verifyNever(() => records.readRecordDailyList(DateTime.now().year));
    verifyNever(() => api.readRecordRepository);
    expect(find.textContaining('7秒'), findsWidgets);
    expect(find.text('按天'), findsNothing);
    expect(find.text('按书'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('首页统计失败重试刷新实际总查询', (tester) async {
    var failed = true;
    when(() => records.getReadRecordOverview(ReadPeriod.all, any()))
        .thenAnswer((_) async {
          if (failed) throw StateError('统计失败');
          return const ReadRecordStatistics();
        });
    await pump(tester, const HomeTabScreen());
    expect(find.byTooltip('重试'), findsOneWidget);
    failed = false;
    await tester.tap(find.byTooltip('重试'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('重试'), findsNothing);
  });

  testWidgets('首页累计时长、今日目标与热力图共用窄接口', (tester) async {
    await pump(tester, const HomeTabScreen());
    expect(find.text('累计阅读'), findsOneWidget);
    expect(find.text('阅读时长'), findsOneWidget);
    verify(() => records.getReadRecordOverview(ReadPeriod.all, any()))
        .called(greaterThanOrEqualTo(1));
    verifyNever(() => records.getAllReadRecordDetails());
    verifyNever(() => records.readRecordDailyList(DateTime.now().year));
    verifyNever(() => api.readRecordRepository);
    expect(tester.takeException(), isNull);
  });
}
