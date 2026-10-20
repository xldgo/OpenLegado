import 'package:flutter_legado/src/features/privacy/privacy_controller.dart';

import 'dart:ui' show SemanticsAction;

import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_legado/src/features/read_records/read_records.dart';
import 'package:flutter_legado/src/widgets/md3_heatmap_calendar.dart';
import 'package:flutter_legado/src/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

class _PublicPrivacy extends PrivacyController {
  @override
  PrivacyState build() => const PrivacyState(loading: false);
}

void main() {
  Widget buildTestHost({required Widget child, double width = 360}) {
    return ProviderScope(
      overrides: [privacyControllerProvider.overrideWith(_PublicPrivacy.new)],
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: SingleChildScrollView(child: child),
            ),
          ),
        ),
      ),
    );
  }

  group('ReadingStatsGridCard', () {
    testWidgets('正常渲染 5 项指标且 360dp 窄屏无溢出', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      const items = [
        StatItem(label: '阅读时长', value: '12小时30分'),
        StatItem(label: '阅读天数', value: '15天'),
        StatItem(label: '读过书籍', value: '8本'),
        StatItem(label: '读完书籍', value: '3本'),
        StatItem(label: '在读书籍', value: '5本'),
      ];

      await tester.pumpWidget(
        buildTestHost(
          width: 360,
          child: const ReadingStatsGridCard(items: items),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('阅读数据'), findsOneWidget);
      expect(find.text('阅读时长'), findsOneWidget);
      expect(find.text('12小时30分'), findsOneWidget);
      expect(find.text('阅读天数'), findsOneWidget);
      expect(find.text('15天'), findsOneWidget);
      expect(find.text('在读书籍'), findsOneWidget);
      expect(find.text('5本'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('空数据时优雅展示空态提示', (tester) async {
      await tester.pumpWidget(
        buildTestHost(child: const ReadingStatsGridCard(items: [])),
      );
      await tester.pumpAndSettle();

      expect(find.text('阅读数据'), findsOneWidget);
      expect(find.text('暂无统计数据'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('ReadingRankingCard', () {
    testWidgets('渲染排行榜数据、前三高亮及点击回调，360dp 窄屏无溢出', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      ReadBookRanking? tappedBook;
      final books = [
        const ReadBookRanking(
          bookName: '诡秘之主',
          author: '爱潜水的乌贼',
          readTimeMs: 7200000,
        ),
        const ReadBookRanking(
          bookName: '道诡异仙',
          author: '狐尾的笔',
          readTimeMs: 3600000,
        ),
        const ReadBookRanking(
          bookName: '宿命之环',
          author: '爱潜水的乌贼',
          readTimeMs: 1800000,
        ),
        const ReadBookRanking(
          bookName: '灵境行者',
          author: '卖报小郎君',
          readTimeMs: 900000,
        ),
      ];

      await tester.pumpWidget(
        buildTestHost(
          width: 360,
          child: ReadingRankingCard(
            topBooks: books,
            onBookTap: (_, b) => tappedBook = b,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('阅读时长榜'), findsOneWidget);
      expect(find.text('诡秘之主'), findsOneWidget);
      expect(find.text('爱潜水的乌贼'), findsWidgets);
      expect(find.text('灵境行者'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);

      await tester.tap(find.text('诡秘之主'));
      await tester.pumpAndSettle();

      expect(tappedBook?.bookName, '诡秘之主');
      expect(tester.takeException(), isNull);
    });

    testWidgets('空列表时优雅展示空态提示', (tester) async {
      await tester.pumpWidget(
        buildTestHost(child: const ReadingRankingCard(topBooks: [])),
      );
      await tester.pumpAndSettle();

      expect(find.text('阅读时长榜'), findsOneWidget);
      expect(find.text('暂无阅读记录'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('ReadingHeatmapCard', () {
    testWidgets('渲染热力图并支持模式切换，360dp 窄屏无溢出', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      Md3HeatmapMode? changedMode;
      final today = DateTime.now();
      final dailySeconds = {DateTime(today.year, today.month, today.day): 3600};
      final dailyCounts = {DateTime(today.year, today.month, today.day): 2};

      await tester.pumpWidget(
        buildTestHost(
          width: 360,
          child: ReadingHeatmapCard(
            dailySeconds: dailySeconds,
            dailyCounts: dailyCounts,
            weeks: 12,
            trailing: IconButton(
              icon: const Icon(Symbols.chevron_right_rounded),
              onPressed: () {},
            ),
            onModeChanged: (m) => changedMode = m,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('阅读热力图'), findsOneWidget);
      expect(find.text('时长'), findsOneWidget);
      expect(find.text('本数'), findsOneWidget);
      expect(find.text('Mon'), findsOneWidget);
      expect(find.text('Wed'), findsOneWidget);
      expect(find.text('Fri'), findsOneWidget);
      expect(find.text('Sun'), findsOneWidget);
      final todayCell = find.byKey(
        ValueKey('heatmap-day-${today.year}-${today.month}-${today.day}'),
      );
      expect(
        tester
            .getRect(todayCell)
            .overlaps(tester.getRect(find.byType(Md3HeatmapCalendar))),
        isTrue,
      );

      // 切换为「本数」
      await tester.tap(find.text('本数'));
      await tester.pumpAndSettle();

      expect(changedMode, Md3HeatmapMode.count);
      expect(find.text('多'), findsOneWidget);
      expect(find.textContaining('格 ='), findsNothing);
      expect(tester.takeException(), isNull);
    });

    for (final dark in [false, true]) {
      testWidgets('热力图${dark ? '暗' : '亮'}主题窄屏与放大文字不溢出', (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.dark : AppTheme.light,
            home: Scaffold(
              body: SingleChildScrollView(
                child: MediaQuery(
                  data: const MediaQueryData(
                    textScaler: TextScaler.linear(1.8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ReadingHeatmapCard(
                      weeks: 52,
                      trailing: IconButton(
                        icon: const Icon(Symbols.chevron_right_rounded),
                        onPressed: () {},
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('阅读热力图'), findsOneWidget);
        expect(find.text('少'), findsOneWidget);
        expect(find.text('多'), findsOneWidget);
        await tester.tap(find.text('本数'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('空数据及 string map 构造不崩溃', (tester) async {
      await tester.pumpWidget(
        buildTestHost(
          child: ReadingHeatmapCard.fromStringMap(
            dailySecondsMap: const {},
            dailyCountsMap: const {},
            weeks: 4,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('阅读热力图'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('ReadingCalendarCard', () {
    testWidgets('渲染星期行及带封面与无阅读的单元格，360dp 窄屏无溢出', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final semantics = tester.ensureSemantics();
      DateTime? tappedDate;
      final refDate = DateTime(2026, 8, 15);
      final dailyTopBook = <String, CalendarBookInfo>{
        '2026-08-15': (bookName: '三体', author: '刘慈欣', coverUrl: null),
      };

      await tester.pumpWidget(
        buildTestHost(
          width: 360,
          child: ReadingCalendarCard(
            referenceDate: refDate,
            dailyTopBook: dailyTopBook,
            onDateTap: (date) => tappedDate = date,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('读书日历'), findsOneWidget);
      expect(find.text('日'), findsOneWidget);
      expect(find.text('六'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);

      try {
        for (final description in ['8月15日 · 《三体》 刘慈欣', '8月16日 无阅读记录']) {
          final node = tester.getSemantics(find.bySemanticsLabel(description));
          expect(
            node.getSemanticsData().hasAction(SemanticsAction.tap),
            description.contains('三体'),
          );
        }
      } finally {
        semantics.dispose();
      }
      await tester.tap(find.text('16'));
      await tester.pumpAndSettle();
      expect(tappedDate, isNull);
      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();
      expect(tappedDate, DateTime(2026, 8, 15));
      expect(tester.takeException(), isNull);
    });

    testWidgets('空数据时正常展示日历网格', (tester) async {
      await tester.pumpWidget(
        buildTestHost(
          child: ReadingCalendarCard(
            referenceDate: DateTime(2026, 8, 1),
            dailyTopBook: const {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('读书日历'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('ReadingTimeBarChartCard', () {
    testWidgets('日模式24个小时柱，窄屏标签稀疏显示且提示含小时区间', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        buildTestHost(
          width: 320,
          child: ReadingTimeBarChartCard(
            period: ReadPeriod.day,
            data: List.generate(
              24,
              (i) =>
                  (date: DateTime(2026, 5, 20, i), seconds: i == 9 ? 900 : 0),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('6'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('18'), findsOneWidget);
      expect(find.text('23'), findsOneWidget);
      expect(find.byTooltip('5月20日 09:00–10:00 · 15分钟'), findsOneWidget);
      expect(find.byTooltip('5月20日 23:00–24:00 · 0秒'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('渲染柱状图、Y轴与X轴标签，360dp 窄屏无溢出', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final weekData = [
        (date: DateTime(2026, 8, 10), seconds: 1800), // 周一
        (date: DateTime(2026, 8, 11), seconds: 3600), // 周二
        (date: DateTime(2026, 8, 12), seconds: 0), // 周三
        (date: DateTime(2026, 8, 13), seconds: 5400), // 周四
        (date: DateTime(2026, 8, 14), seconds: 7200), // 周五
        (date: DateTime(2026, 8, 15), seconds: 9000), // 周六
        (date: DateTime(2026, 8, 16), seconds: 1800), // 周日
      ];

      await tester.pumpWidget(
        buildTestHost(
          width: 360,
          child: ReadingTimeBarChartCard(
            data: weekData,
            period: ReadPeriod.week,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('阅读时长分布'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(find.text('一'), findsOneWidget);
      expect(find.text('日'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('月模式与年模式标签渲染正常', (tester) async {
      final monthData = List.generate(
        30,
        (i) => (date: DateTime(2026, 8, i + 1), seconds: i * 100),
      );

      await tester.pumpWidget(
        buildTestHost(
          child: ReadingTimeBarChartCard(
            data: monthData,
            period: ReadPeriod.month,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);
      expect(find.text('30'), findsOneWidget);

      final yearData = List.generate(
        12,
        (i) => (date: DateTime(2026, i + 1, 1), seconds: 3600),
      );

      await tester.pumpWidget(
        buildTestHost(
          child: ReadingTimeBarChartCard(
            data: yearData,
            period: ReadPeriod.year,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1月'), findsOneWidget);
      expect(find.text('12月'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('空数据展示优雅提示', (tester) async {
      await tester.pumpWidget(
        buildTestHost(
          child: const ReadingTimeBarChartCard(
            data: [],
            period: ReadPeriod.day,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('阅读时长分布'), findsOneWidget);
      expect(find.text('暂无时长分布数据'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
