import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../../models/models.dart';
import '../bookshelf/bookshelf.dart';
import '../../app/routing/route_names.dart';
import '../../utils/book_open_utils.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/legado_app_bar.dart';
import 'read_record_overview_notifier.dart';
import 'read_record_overview_state.dart';
import 'read_record_screen.dart' show formatDuring;
import 'widgets/reading_calendar_card.dart';
import 'widgets/read_record_day_details_sheet.dart';
import 'widgets/reading_heatmap_card.dart';
import 'widgets/reading_ranking_card.dart';
import 'widgets/reading_stats_grid_card.dart';
import 'widgets/reading_time_bar_chart_card.dart';

/// 阅读总览页面（对齐上游 HapeLee/legado-with-MD3 的 ReadRecordOverviewScreen）
///
/// 展示按日、周、月、年、总周期统计的阅读时长、分布柱状图、指标网格、阅读热力图、
/// 阅读时长排行与读书日历。支持点击书籍快速跳转阅读或搜索。
class ReadRecordOverviewScreen extends ConsumerStatefulWidget {
  const ReadRecordOverviewScreen({super.key});

  @override
  ConsumerState<ReadRecordOverviewScreen> createState() =>
      _ReadRecordOverviewScreenState();
}

class _ReadRecordOverviewScreenState
    extends ConsumerState<ReadRecordOverviewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const List<({ReadPeriod period, String label})> _periods = [
    (period: ReadPeriod.day, label: '日'),
    (period: ReadPeriod.week, label: '周'),
    (period: ReadPeriod.month, label: '月'),
    (period: ReadPeriod.year, label: '年'),
    (period: ReadPeriod.all, label: '总'),
  ];

  @override
  void initState() {
    super.initState();
    final initialPeriod = ref.read(readRecordOverviewNotifierProvider).period;
    final initialIndex = _periods.indexWhere((p) => p.period == initialPeriod);
    _tabController = TabController(
      length: _periods.length,
      vsync: this,
      initialIndex: initialIndex >= 0 ? initialIndex : 0,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged(int index) {
    if (index >= 0 && index < _periods.length) {
      final targetPeriod = _periods[index].period;
      ref
          .read(readRecordOverviewNotifierProvider.notifier)
          .setPeriod(targetPeriod);
    }
  }

  /// 书籍点击交互处理
  Future<void> _handleBookTap(
    BuildContext context,
    WidgetRef ref,
    String bookName,
    String author,
  ) async {
    final books = ref.read(bookshelfNotifierProvider).books;
    Book? matchedBook;

    // 1. 先精准匹配书名与作者
    for (final b in books) {
      if (b.name == bookName && b.author == author) {
        matchedBook = b;
        break;
      }
    }

    // 2. 若未找到，再按书名匹配
    if (matchedBook == null && author.isEmpty) {
      for (final b in books) {
        if (b.name == bookName) {
          matchedBook = b;
          break;
        }
      }
    }

    if (matchedBook != null) {
      await BookOpenUtils.openBook(context, ref, matchedBook);
    } else {
      await Navigator.pushNamed(context, AppRoutes.search, arguments: bookName);
    }
  }

  /// 周期日期格式化
  String _formatDateForPeriod(ReadPeriod period, DateTime date) {
    switch (period) {
      case ReadPeriod.day:
        return '${date.year}年${date.month}月${date.day}日';
      case ReadPeriod.week:
        // 计算当前周的周一与周日（DateTime.weekday: 1 为周一, 7 为周日）
        final monday = date.subtract(Duration(days: date.weekday - 1));
        final sunday = monday.add(const Duration(days: 6));
        return '${monday.month}.${monday.day} - ${sunday.month}.${sunday.day}';
      case ReadPeriod.month:
        return '${date.year}年${date.month}月';
      case ReadPeriod.year:
        return '${date.year}年';
      case ReadPeriod.all:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(readRecordOverviewNotifierProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // 同步 TabController 的 index
    final periodIndex = _periods.indexWhere((p) => p.period == state.period);
    if (periodIndex >= 0 && _tabController.index != periodIndex) {
      _tabController.animateTo(periodIndex);
    }

    return AppScaffold(
      topBar: const LegadoAppBar(title: Text('阅读总览'), showBack: true),
      body: Column(
        children: [
          // 周期选择器
          Material(
            color: cs.surface,
            child: TabBar(
              controller: _tabController,
              // 固定周期标签等宽铺满。
              isScrollable: false,
              tabAlignment: TabAlignment.fill,
              onTap: _onTabChanged,
              tabs: _periods.map((p) => Tab(text: p.label)).toList(),
            ),
          ),

          // 日期导航器（all 模式下不展示）
          if (state.period != ReadPeriod.all)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: cs.surfaceContainerLowest,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Symbols.chevron_left_rounded),
                    tooltip: '上一周期',
                    onPressed: () {
                      ref
                          .read(readRecordOverviewNotifierProvider.notifier)
                          .previousPeriod();
                    },
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        _formatDateForPeriod(state.period, state.referenceDate),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Symbols.chevron_right_rounded),
                    tooltip: '下一周期',
                    onPressed: () {
                      ref
                          .read(readRecordOverviewNotifierProvider.notifier)
                          .nextPeriod();
                    },
                  ),
                ],
              ),
            ),

          // 内容滚动列表
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (state.isLoading) const LinearProgressIndicator(),
                if (state.error != null)
                  ListTile(
                    title: Text(state.error!),
                    trailing: IconButton(
                      icon: const Icon(Symbols.refresh_rounded),
                      tooltip: '重试',
                      onPressed: () => ref
                          .read(readRecordOverviewNotifierProvider.notifier)
                          .refresh(),
                    ),
                  ),
                // (1) 阅读时长分布柱状图（all 周期不展示）
                if (state.period != ReadPeriod.all) ...[
                  ReadingTimeBarChartCard(
                    data: state.dailyTimeData,
                    period: state.period,
                  ),
                  const SizedBox(height: 12),
                ],

                // (2) 阅读统计指标网格
                ReadingStatsGridCard(
                  items: [
                    StatItem(
                      label: '阅读时长',
                      value: formatDuring(state.totalTimeMs),
                    ),
                    StatItem(label: '阅读天数', value: '${state.readingDays}天'),
                    StatItem(label: '读过书籍', value: '${state.totalBooks}本'),
                    StatItem(label: '读完书籍', value: '${state.finishedBooks}本'),
                    StatItem(label: '在读书籍', value: '${state.readingBooks}本'),
                  ],
                ),
                // 全量汇总卡片只在「总」周期展示。
                if (state.period == ReadPeriod.all) ...[
                  const SizedBox(height: 12),

                  // (3) 阅读热力图
                  ReadingHeatmapCard.fromStringMap(
                    dailySecondsMap: state.allDailyTimes,
                    dailyCountsMap: state.allDailyCounts,
                  ),
                  const SizedBox(height: 12),

                  // (4) 阅读时长榜
                  ReadingRankingCard(
                    topBooks: state.topBooks,
                    onBookTap: (ranking) => _handleBookTap(
                      context,
                      ref,
                      ranking.bookName,
                      ranking.author,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // (5) 读书日历
                  ReadingCalendarCard(
                    referenceDate: state.referenceDate,
                    dailyTopBook: state.dailyTopBook,
                    onDateTap: (date) =>
                        showReadRecordDayDetails(context, date),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
