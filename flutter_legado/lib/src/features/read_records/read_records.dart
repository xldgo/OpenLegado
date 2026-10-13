// 阅读记录的对外入口；功能内部直接引用各自依赖。— Codex + UI
export 'read_record_notifier.dart'
    show ReadRecordNotifier, readRecordNotifierProvider;
export 'read_record_repository_provider.dart' show readRecordRepositoryProvider;
export 'read_record_screen.dart' show ReadRecordScreen, formatDuring;
export 'read_record_state.dart' show ReadRecordState, ReadRecordSortMode;
export 'widgets/read_record_daily_view.dart'
    show
        ReadAchievementCard,
        ReadRecordDailyView,
        DailyReadEntry,
        groupDailyByDay;
