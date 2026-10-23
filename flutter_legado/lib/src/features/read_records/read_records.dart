// 阅读记录的对外入口；功能内部直接引用各自依赖。— Codex + UI
export 'read_record_notifier.dart'
    show ReadRecordNotifier, readRecordNotifierProvider;
export 'read_record_overview_notifier.dart'
    show
        ReadRecordOverviewNotifier,
        readRecordOverviewNotifierProvider,
        homeReadRecordOverviewProvider;
export 'read_record_overview_screen.dart' show ReadRecordOverviewScreen;
export 'read_record_overview_state.dart'
    show ReadPeriod, ReadBookRanking, ReadRecordOverviewState;
export 'read_record_repository_provider.dart' show readRecordRepositoryProvider;
export 'read_record_screen.dart' show ReadRecordScreen, formatDuring;
export 'read_record_state.dart'
    show ReadRecordState, ReadRecordSortMode, ReadRecordDisplayMode;
export 'widgets/reading_calendar_card.dart'
    show ReadingCalendarCard, CalendarBookInfo;
export 'widgets/reading_heatmap_card.dart' show ReadingHeatmapCard;
export 'widgets/reading_ranking_card.dart' show ReadingRankingCard;
export 'widgets/reading_stats_grid_card.dart'
    show ReadingStatsGridCard, StatItem;
export 'widgets/reading_time_bar_chart_card.dart'
    show ReadingTimeBarChartCard, DailyTimeBarItem;

export 'read_record_dataset.dart'
    show
        ReadRecordDataset,
        readRecordDatasetProvider,
        readRecordRecordsProvider;

export 'widgets/read_record_day_details_sheet.dart'
    show showReadRecordDayDetails;
