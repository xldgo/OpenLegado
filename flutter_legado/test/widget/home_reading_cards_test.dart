import 'package:flutter_legado/src/data/repositories/mock_read_record_repository.dart';
import 'package:flutter_legado/src/features/read_records/read_records.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/providers/providers.dart';
import 'package:flutter_legado/src/screens/home_tab_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../mocks/mocks.dart';

class _FakeOverviewNotifier extends ReadRecordOverviewNotifier {
  final ReadRecordOverviewState _mockState;

  _FakeOverviewNotifier(this._mockState);

  @override
  ReadRecordOverviewState build() => _mockState;
}

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
      ReadBookRanking(
        bookName: '诡秘之主',
        author: '爱潜水的乌贼',
        readTimeMs: 3600000,
      ),
      ReadBookRanking(
        bookName: '宿命之环',
        author: '爱潜水的乌贼',
        readTimeMs: 1800000,
      ),
    ],
    dailyTopBook: const {
      '2026-05-20': (
        bookName: '诡秘之主',
        author: '爱潜水的乌贼',
        coverUrl: null,
      ),
    },
    allDailyTimes: const {
      '2026-05-20': 3600,
      '2026-05-19': 1800,
    },
    allDailyCounts: const {
      '2026-05-20': 1,
      '2026-05-19': 1,
    },
  );

  Widget createTestWidget({
    required MockRustApi mockApi,
    ReadRecordOverviewState? overviewState,
    double width = 360,
    double height = 800,
  }) {
    final state = overviewState ?? sampleOverviewState;
    return ProviderScope(
      overrides: [
        bookApiProvider.overrideWithValue(mockApi),
        readRecordOverviewNotifierProvider.overrideWith(
          () => _FakeOverviewNotifier(state),
        ),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(width, height)),
          child: const Scaffold(
            body: HomeTabScreen(),
          ),
        ),
      ),
    );
  }

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
    when(() => mockApi.bookshelfRepository.getBooks())
        .thenAnswer((_) async => <Book>[
              Book(bookUrl: 'u1', name: '诡秘之主', author: '爱潜水的乌贼'),
            ]);
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
      createTestWidget(
        mockApi: mockApi,
        width: 360,
        height: 800,
      ),
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
}
