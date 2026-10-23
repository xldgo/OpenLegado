import '../fixtures/routing_test_app.dart';

import 'package:flutter_legado/src/app/routing/route_arguments.dart';
import 'package:flutter_legado/src/features/privacy/privacy_controller.dart';

import 'package:flutter_legado/src/features/read_records/read_records.dart';
import 'package:flutter_legado/src/app/routing/route_names.dart';
import 'package:flutter_legado/src/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

class _FakeOverviewNotifier extends ReadRecordOverviewNotifier {
  final ReadRecordOverviewState _mockState;

  _FakeOverviewNotifier(this._mockState);

  @override
  ReadRecordOverviewState build() {
    return _mockState;
  }

  @override
  void setPeriod(ReadPeriod period) {
    state = state.copyWith(period: period);
  }

  @override
  void previousPeriod() {
    final current = state.referenceDate;
    state = state.copyWith(
      referenceDate: current.subtract(const Duration(days: 1)),
    );
  }

  @override
  void nextPeriod() {
    final current = state.referenceDate;
    state = state.copyWith(referenceDate: current.add(const Duration(days: 1)));
  }
}

// 总览交互夹具显式提供公开状态，隐私行为由独立测试覆盖。
class _PublicPrivacy extends PrivacyController {
  @override
  PrivacyState build() => const PrivacyState(loading: false);
}

void main() {
  final sampleState = ReadRecordOverviewState(
    period: ReadPeriod.day,
    referenceDate: DateTime(2026, 5, 20),
    totalTimeMs: 3600000, // 1小时
    readingDays: 5,
    totalBooks: 4,
    finishedBooks: 2,
    readingBooks: 2,
    dailyTimeData: [(date: DateTime(2026, 5, 20), seconds: 3600)],
    topBooks: const [
      ReadBookRanking(bookName: '诡秘之主', author: '爱潜水的乌贼', readTimeMs: 3600000),
    ],
    dailyTopBook: const {
      '2026-05-20': (bookName: '诡秘之主', author: '爱潜水的乌贼', coverUrl: null),
    },
    allDailyTimes: const {'2026-05-20': 3600},
    allDailyCounts: const {'2026-05-20': 1},
    isLoading: false,
  );

  Widget createTestWidget({
    ReadRecordOverviewState? state,
    ThemeMode themeMode = ThemeMode.light,
  }) {
    final effectiveState = state ?? sampleState;
    return ProviderScope(
      overrides: [
        privacyControllerProvider.overrideWith(_PublicPrivacy.new),
        readRecordOverviewNotifierProvider.overrideWith(
          () => _FakeOverviewNotifier(effectiveState),
        ),
      ],
      child: RoutingTestApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        home: const ReadRecordOverviewScreen(),
      ),
    );
  }

  group('ReadRecordOverviewScreen 基本渲染与组件存在性', () {
    testWidgets('日周期渲染时长分布与指标，不展示汇总卡片，360dp无溢出', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // 1. 顶栏标题「阅读总览」与返回按钮
      expect(find.text('阅读总览'), findsWidgets);

      // 2. TabBar 5 个周期
      expect(find.text('日'), findsOneWidget);
      expect(find.text('周'), findsOneWidget);
      expect(find.text('月'), findsOneWidget);
      expect(find.text('年'), findsOneWidget);
      expect(find.text('总'), findsOneWidget);

      // 3. 日期导航器（day 周期下格式化为 2026年5月20日）
      expect(find.text('2026年5月20日'), findsOneWidget);
      expect(find.byIcon(Symbols.chevron_left_rounded), findsOneWidget);
      expect(find.byIcon(Symbols.chevron_right_rounded), findsOneWidget);

      // 4. 卡片存在性检查
      expect(find.text('阅读时长分布'), findsOneWidget);
      expect(find.text('阅读数据'), findsOneWidget);
      expect(find.byType(ReadingHeatmapCard), findsNothing);
      expect(find.byType(ReadingRankingCard), findsNothing);
      expect(find.byType(ReadingCalendarCard), findsNothing);

      // 5. 校验指标项卡片类型
      expect(find.byType(ReadingStatsGridCard), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('实际亮暗主题下切换周期不触发标签对齐断言', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('周'));
      await tester.pumpAndSettle();

      final tab = tester.widget<TabBar>(find.byType(TabBar));
      expect(tab.controller?.index, 1);
      expect(find.byType(ReadingHeatmapCard), findsNothing);
      expect(find.byType(ReadingRankingCard), findsNothing);
      expect(find.byType(ReadingCalendarCard), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(createTestWidget(themeMode: ThemeMode.dark));
      await tester.pumpAndSettle();
      await tester.tap(find.text('月'));
      await tester.pumpAndSettle();
      expect(tester.widget<TabBar>(find.byType(TabBar)).controller?.index, 2);
      for (final label in ['月', '年', '日']) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(find.byType(ReadingHeatmapCard), findsNothing);
        expect(find.byType(ReadingRankingCard), findsNothing);
        expect(find.byType(ReadingCalendarCard), findsNothing);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('总周期显示汇总卡片，切回日周期后全部隐藏', (tester) async {
      final allState = sampleState.copyWith(period: ReadPeriod.all);
      await tester.pumpWidget(createTestWidget(state: allState));
      await tester.pumpAndSettle();

      // 日期导航按钮不应显示
      expect(find.byIcon(Symbols.chevron_left_rounded), findsNothing);
      expect(find.byIcon(Symbols.chevron_right_rounded), findsNothing);

      // 柱状图卡片不应显示
      expect(find.text('阅读时长分布'), findsNothing);

      // 其余卡片正常显示
      expect(find.text('阅读数据'), findsOneWidget);
      expect(find.text('阅读热力图'), findsOneWidget);

      final scrollableFinder = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('阅读时长榜'),
        300,
        scrollable: scrollableFinder,
      );
      expect(find.text('阅读时长榜'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('读书日历'),
        300,
        scrollable: scrollableFinder,
      );
      expect(find.text('读书日历'), findsOneWidget);
      await tester.tap(
        find.descendant(of: find.byType(TabBar), matching: find.text('日')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ReadingHeatmapCard), findsNothing);
      expect(find.byType(ReadingRankingCard), findsNothing);
      expect(find.byType(ReadingCalendarCard), findsNothing);
      expect(find.byType(ReadingTimeBarChartCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('点击前一周期与后一周期按钮触发状态切换', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('2026年5月20日'), findsOneWidget);

      await tester.tap(find.byTooltip('上一周期'));
      await tester.pumpAndSettle();
      expect(find.text('2026年5月19日'), findsOneWidget);

      await tester.tap(find.byTooltip('下一周期'));
      await tester.pumpAndSettle();
      expect(find.text('2026年5月20日'), findsOneWidget);
    });

    testWidgets('点击排行卡片书籍：未在书架找到时跳转 search 路由', (tester) async {
      String? pushedRoute;
      Object? pushedArgs;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            privacyControllerProvider.overrideWith(_PublicPrivacy.new),
            readRecordOverviewNotifierProvider.overrideWith(
              () => _FakeOverviewNotifier(
                sampleState.copyWith(period: ReadPeriod.all),
              ),
            ),
          ],
          child: RoutingTestApp(
            onGenerateRoute: (settings) {
              if (settings.name == AppRoutes.search) {
                pushedRoute = settings.name;
                pushedArgs = settings.arguments;
                return MaterialPageRoute(
                  builder: (_) => const Scaffold(body: Text('搜索页')),
                );
              }
              return null;
            },
            home: const ReadRecordOverviewScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollableFinder = find.byType(Scrollable).first;
      // 先滚动到阅读时长榜卡片
      await tester.scrollUntilVisible(
        find.text('阅读时长榜'),
        300,
        scrollable: scrollableFinder,
      );
      expect(find.text('阅读时长榜'), findsOneWidget);

      final bookFinder = find.text('诡秘之主');
      await tester.scrollUntilVisible(
        bookFinder,
        300,
        scrollable: scrollableFinder,
      );
      expect(bookFinder, findsWidgets);

      await tester.tap(bookFinder.first);
      await tester.pumpAndSettle();

      expect(pushedRoute, AppRoutes.search);
      expect((pushedArgs as SearchRouteArgs).query, '诡秘之主');
    });
  });
}
