import '../fixtures/app_test_api.dart';

import 'package:flutter_legado/src/data/repositories/mock_read_record_repository.dart';
import 'package:flutter_legado/src/features/read_records/read_records.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/screens/home_tab_screen.dart';
import 'package:flutter_legado/src/routes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../mocks/mocks.dart';

void main() {
  setUpAll(registerFallbacks);

  final sampleOverviewState = ReadRecordOverviewState(
    period: ReadPeriod.month,
    referenceDate: DateTime(2026, 5, 20),
    totalTimeMs: 7200000,
    readingDays: 12,
    totalBooks: 5,
    finishedBooks: 2,
    readingBooks: 3,
    topBooks: const [
      ReadBookRanking(bookName: '诡秘之主', author: '爱潜水的乌贼', readTimeMs: 3600000),
      ReadBookRanking(bookName: '宿命之环', author: '爱潜水的乌贼', readTimeMs: 1800000),
    ],
    dailyTopBook: const {
      '2026-05-20': (bookName: '诡秘之主', author: '爱潜水的乌贼', coverUrl: null),
    },
    allDailyTimes: const {'2026-05-20': 3600, '2026-05-19': 1800},
    allDailyCounts: const {'2026-05-20': 1, '2026-05-19': 1},
  );

  Widget createTestWidget({
    required MockRustApi mockApi,
    ReadRecordOverviewState? overviewState,
    double width = 360,
    double height = 800,
  }) {
    final state = overviewState ?? sampleOverviewState;
    return ProviderScope(
      overrides: mergeTestOverrides([
        ...mockApi.overrides,
        homeReadRecordOverviewProvider.overrideWithValue(state),
      ]),
      child: MaterialApp(
        routes: {
          AppRoutes.readRecordOverview: (_) =>
              const Scaffold(body: Text('总览目标页')),
          AppRoutes.readRecord: (_) => const Scaffold(body: Text('记录目标页')),
        },
        home: MediaQuery(
          data: MediaQueryData(size: Size(width, height)),
          child: const Scaffold(body: HomeTabScreen()),
        ),
      ),
    );
  }

  testWidgets('首页累计阅读进入总览，阅读时长进入记录', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final mockApi = MockRustApi();
    when(() => mockApi.bookshelfRepository.getBooks())
        .thenAnswer((_) async => <Book>[]);
    when(() => mockApi.readRecordRepository)
        .thenReturn(MockReadRecordRepository());
    await tester.pumpWidget(createTestWidget(mockApi: mockApi));
    await tester.pumpAndSettle();
    await tester.tap(find.text('累计阅读'));
    await tester.pumpAndSettle();
    expect(find.text('总览目标页'), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('阅读时长'));
    await tester.pumpAndSettle();
    expect(find.text('记录目标页'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('验证渲染 HomeTabScreen 时页面中包含三大核心卡片', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final mockApi = MockRustApi();
    when(() => mockApi.bookshelfRepository.getBooks())
        .thenAnswer((_) async => <Book>[]);
    when(() => mockApi.readRecordRepository)
        .thenReturn(MockReadRecordRepository());

    await tester.pumpWidget(createTestWidget(mockApi: mockApi));
    await tester.pumpAndSettle();

    final scrollableFinder = find.byType(Scrollable).first;
    expect(find.byType(ReadingHeatmapCard), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byType(ReadingRankingCard),
      300,
      scrollable: scrollableFinder,
    );
    expect(find.byType(ReadingRankingCard), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byType(ReadingCalendarCard),
      300,
      scrollable: scrollableFinder,
    );
    expect(find.byType(ReadingCalendarCard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('验证在 360dp 窄屏下无 RenderFlex 溢出', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final mockApi = MockRustApi();
    when(() => mockApi.bookshelfRepository.getBooks()).thenAnswer(
      (_) async => <Book>[Book(bookUrl: 'u1', name: '诡秘之主', author: '爱潜水的乌贼')],
    );
    final mockRepo = MockReadRecordRepository();
    await mockRepo.putReadRecord(
      ReadRecord(
        bookName: '诡秘之主',
        readTime: 3600000,
        lastRead: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    when(() => mockApi.readRecordRepository).thenReturn(mockRepo);

    await tester.pumpWidget(
      createTestWidget(mockApi: mockApi, width: 360, height: 800),
    );
    await tester.pumpAndSettle();

    final scrollableFinder = find.byType(Scrollable).first;
    expect(find.byType(ReadingHeatmapCard), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byType(ReadingRankingCard),
      300,
      scrollable: scrollableFinder,
    );
    expect(find.byType(ReadingRankingCard), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byType(ReadingCalendarCard),
      300,
      scrollable: scrollableFinder,
    );
    expect(find.byType(ReadingCalendarCard), findsOneWidget);

    expect(tester.takeException(), isNull);
  });
  testWidgets('今日目标仅编辑按钮打开数字输入，范围校验与保存取消正确', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final mockApi = MockRustApi();
    when(() => mockApi.bookshelfRepository.getBooks())
        .thenAnswer((_) async => <Book>[]);
    when(() => mockApi.readRecordRepository)
        .thenReturn(MockReadRecordRepository());
    await tester.pumpWidget(createTestWidget(mockApi: mockApi));
    await tester.pumpAndSettle();

    await tester.tap(find.text('今日阅读目标'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    await tester.tap(find.byTooltip('编辑目标'));
    await tester.pumpAndSettle();
    expect(find.text('设定阅读目标'), findsOneWidget);
    expect(find.text('目标（分钟）'), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
    final field = find.byType(TextFormField);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      '30',
    );
    for (final invalid in ['', '0', '1441', '99999999999999999999999999999']) {
      await tester.enterText(field, invalid);
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
    }
    await tester.enterText(field, '1440');
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    await tester.enterText(field, '3x5');
    await tester.pumpAndSettle();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      '35',
    );
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      (await SharedPreferences.getInstance()).getInt('homeReadGoalMinutes'),
      35,
    );
    expect(find.textContaining('/ 35'), findsOneWidget);
    await tester.tap(find.byTooltip('编辑目标'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '1');
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(
      (await SharedPreferences.getInstance()).getInt('homeReadGoalMinutes'),
      35,
    );
    expect(find.textContaining('/ 35'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
