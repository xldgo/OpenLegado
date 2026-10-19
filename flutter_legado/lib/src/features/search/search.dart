// 搜索功能对外入口；内部直接引用所需依赖。— Codex + UI
export 'search_access_providers.dart'
    show searchServiceProvider, searchHistoryRepositoryProvider;
export 'search_content_screen.dart' show SearchContentScreen;
export '../../domain/services/content_search_matcher.dart' show findContentHits;
export 'search_notifier.dart' show SearchNotifier, searchNotifierProvider;
export 'search_screen.dart' show SearchScreen;
export 'search_state.dart'
    show SearchState, SearchStateDisplay, SearchSourceFailure;
export 'widgets/search_filter_panel.dart' show SearchFilterPanel;
