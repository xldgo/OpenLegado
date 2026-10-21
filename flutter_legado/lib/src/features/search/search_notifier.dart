import '../../utils/error_message.dart';
export 'search_state.dart';
import '../book_sources/book_source_repository_provider.dart';
import '../../providers/app_log_repository_provider.dart';
import '../../domain/services/search_result_aggregator.dart';
import '../../domain/services/search_session.dart';
import 'search_access_providers.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import 'search_state.dart';
import 'search_settings_provider.dart';

/// 书源分组拆分正则（对标原版 AppPattern.splitGroupRegex：[,;，；]）
final _splitGroupRegex = RegExp(r'[,;，；]');

/// 搜索页 Riverpod Notifier
///
/// 消费窄搜索与历史接口，管理展示、范围和增量结果；原生调度由 Rust 负责。
/// 批次解码、执行会话及纯增量聚合由独立模块承担。— Codex + UI
class SearchNotifier extends Notifier<SearchState> {
  /// 历史保留上限（UI 展示截断，对标原版）
  static const _maxHistory = 20;

  /// 查询绑定、清理屏障与资源释放由会话拥有。— Codex + UI
  SearchSession? _session;
  Future<void>? _stopping;
  bool _disposed = false;
  int _lifecycleGeneration = 0;
  int _scopeRevision = 0;
  Future<void> _scopeRestored = Future.value();

  /// 当前查询使用的精准搜索快照；只在流启动前从设置来源派生。
  bool _keepOther = true;

  /// 搜索序号（使旧搜索的迟到批次/回调失效，对齐原版 searchID）
  int _searchSeq = 0;

  final _aggregator = SearchResultAggregator();

  /// 结果列表节流重建间隔（2026-08-24：修复逐批次全量重聚合 + 全量替换
  /// 导致的搜索卡顿；对齐原版增量渲染语义）
  static const _flushInterval = Duration(milliseconds: 150);

  /// 结果列表节流重建定时器（至多每 [_flushInterval] 触发一次全量
  /// 聚合快照 + state 回写）— Qoder UI
  Timer? _resultsFlushTimer;

  /// 待回写的进度字段（批次仅追加累积表，由 [_flushResults] 批量回写，
  /// 避免每批次一次 state 通知引发整页重建）— Qoder UI
  int _pendingSearchedCount = 0;
  int _pendingTotalCount = 0;
  bool? _pendingHasMore;

  @override
  SearchState build() {
    // Riverpod 失效重建会复用 Notifier，恢复新生命周期而不复用旧草稿。
    _disposed = false;
    final lifecycle = ++_lifecycleGeneration;
    _aggregator.reset();
    _pendingSearchedCount = 0;
    _pendingTotalCount = 0;
    _pendingHasMore = null;
    ref.onDispose(() {
      _disposed = true;
      _lifecycleGeneration++;
      unawaited(_invalidateSession());
    });
    // 延迟到 build() 返回后读取，范围恢复单独提供搜索启动屏障。
    final scopeRevision = _scopeRevision;
    _scopeRestored = Future.microtask(() async {
      if (!_ownsLifecycle(lifecycle)) return;
      await _restoreSearchScope(scopeRevision);
    });
    Future.microtask(() async {
      if (!_ownsLifecycle(lifecycle)) return;
      await loadHistory();
    });
    return const SearchState();
  }

  // ===== 搜索历史 =====

  /// 加载搜索历史（经 SearchHistoryRepository.getSearchHistory 从 Rust 读取，取关键词列表）
  Future<void> loadHistory() async {
    final lifecycle = _lifecycleGeneration;
    if (!_ownsLifecycle(lifecycle)) return;
    try {
      final keywords = await ref
          .read(searchHistoryRepositoryProvider)
          .getSearchHistory();
      if (!_ownsLifecycle(lifecycle)) return;
      state = state.copyWith(
        searchHistory: keywords.map((k) => k.word).toList(),
      );
    } catch (e) {
      // 历史加载失败不阻断搜索主流程，保持空历史
      // [审计修复 §4.1] debugPrint 留痕 — Qoder
      debugPrint('搜索历史加载失败: $e');
    }
  }

  /// 添加到搜索历史（客户端去重置顶 + 截断 20 条，并经历史 Repository 持久化）
  ///
  /// 客户端维护去重/截断后的展示列表（即时 UI 反馈，且 Mock/真实后端行为一致）；
  /// Rust `addSearchKeyword` 负责持久化（真实后端按 keyword 去重）。
  Future<void> addToHistory(String keyword) async {
    final history = [...state.searchHistory];
    history.remove(keyword);
    history.insert(0, keyword);
    final trimmed = history.length > _maxHistory
        ? history.sublist(0, _maxHistory)
        : history;
    state = state.copyWith(searchHistory: trimmed);
    try {
      await ref
          .read(searchHistoryRepositoryProvider)
          .addSearchKeyword(keyword, '');
    } catch (e) {
      // 持久化失败不阻断 UI 历史展示
      // [审计修复 §4.1] debugPrint 留痕 — Qoder
      debugPrint('搜索历史持久化失败: $e');
    }
  }

  /// 清空搜索历史（同步清本地状态并经历史 Repository 清后端）
  Future<void> clearHistory() async {
    state = state.copyWith(searchHistory: []);
    try {
      await ref.read(searchHistoryRepositoryProvider).clearSearchHistory();
    } catch (e) {
      // 后端清空失败不阻断 UI
      // [审计修复 §4.1] debugPrint 留痕 — Qoder
      debugPrint('搜索历史后端清空失败: $e');
    }
  }

  /// 删除单条搜索历史（对齐原版 HistoryKeyAdapter 长按删除）
  Future<void> deleteHistoryItem(String keyword) async {
    final history = [...state.searchHistory]..remove(keyword);
    state = state.copyWith(searchHistory: history);
    try {
      await ref
          .read(searchHistoryRepositoryProvider)
          .deleteSearchKeyword(keyword);
    } catch (e) {
      debugPrint('删除搜索历史项失败: $e');
    }
  }

  /// 更新输入框实时文本（驱动联想过滤，见 [SearchState.suggestions]）
  void setInput(String text) {
    if (state.inputText == text) return;
    state = state.copyWith(inputText: text);
  }

  // ===== 搜索 =====

  /// 执行搜索（对齐 SearchViewModel/SearchModel：关键词非空 → 记录历史 →
  /// 逐源流式搜索）
  ///
  /// 使用 Rust `searchMultiStream` 逐源渐进渲染（对齐原版 flow 逐源
  /// onSearchSuccess + x/y 进度语义）；发起前取消上一次搜索
  /// （对齐原版 `searchModel.cancelSearch`）。
  Future<void> search(String keyword) async {
    final trimmed = keyword.trim();
    if (_disposed || trimmed.isEmpty) return;

    // 请求先取得身份并绑定能力，准备或清理期间也可以取消。— Codex + UI
    final service = ref.read(searchServiceProvider);
    final settings = ref.read(searchSettingsRepositoryProvider);
    final scopeRestored = _scopeRestored;
    final stopping = _invalidateSession();
    final seq = _searchSeq;
    final session = SearchSession(service);
    _session = session;

    // G-B-01：新关键词 → 会话重置（页码归 1、累积表清空）；
    // G-B-02：hasMore 乐观置 true（对齐原版 SearchViewModel L135，
    // 首页完成后由批次 has_more 覆写）；isManualStop 复位（原版 onQueryTextSubmit L203）
    _aggregator.reset(keyword: trimmed);
    // [2026-08-24] 重置节流状态（防旧批次定时器/待写字段泄漏进新搜索）— Qoder UI
    _resultsFlushTimer?.cancel();
    _resultsFlushTimer = null;
    _pendingHasMore = null;
    _pendingSearchedCount = 0;
    _pendingTotalCount = 0;
    state = state.copyWith(
      keyword: trimmed,
      isLoading: true,
      error: null,
      results: const [],
      searchedCount: 0,
      totalCount: 0,
      searchPage: 1,
      hasMore: true,
      isPaused: false,
      isManualStop: false,
      // [队列④ P1-B] 新关键词 → 失败源横幅随会话重置
      failedSources: const [],
    );
    try {
      await stopping;
      if (!_ownsSession(session, seq)) return;
      await scopeRestored;
      if (!_ownsSession(session, seq)) return;
      await addToHistory(trimmed);
      if (!_ownsSession(session, seq)) return;
      final sourceUrls = await _resolveSearchSources();
      if (!_ownsSession(session, seq)) return;
      // 有筛选条件但解析结果为空，说明所选分组/书源无有效书源
      if (sourceUrls != null && sourceUrls.isEmpty) {
        state = state.copyWith(error: '所选筛选范围内无有效书源，请调整筛选条件', isLoading: false);
        return;
      }
      // 原生搜索读取 config 表，先完成当前根的配置同步与已提交写入。
      await settings.reloadRuntime();
      await settings.settled();
      if (!_ownsSession(session, seq)) return;
      _keepOther = !settings.current.precisionSearch;
      _attachSearchStream(session, trimmed, 1, sourceUrls, seq);
    } catch (e) {
      if (!_ownsSession(session, seq)) return;
      state = state.copyWith(error: errorMessage(e), isLoading: false);
      unawaited(_invalidateSession());
    }
  }

  /// 加载下一页（批次B G-B-01/G-B-02：对齐原版 SearchActivity FAB play +
  /// scrollToBottom → viewModel.search("")，同 searchId → page++）
  ///
  /// 守卫：非加载中、非手动停止、hasMore 为真、关键词非空；
  /// 结果 APPEND（不清空累积表），对齐原版同会话跨页累积语义。
  Future<void> loadNextPage() async {
    if (_disposed) return;
    final s = state;
    if (s.isLoading || s.isManualStop || !s.hasMore) return;
    final keyword = s.keyword.trim();
    if (keyword.isEmpty) return;

    // G-B-01：同关键词续页 → page++（原版 SearchModel.searchPage++）
    final nextPage = s.searchPage + 1;
    final settings = ref.read(searchSettingsRepositoryProvider);
    final seq = ++_searchSeq;
    final session = _session ?? SearchSession(ref.read(searchServiceProvider));
    _session = session;
    // [2026-08-24] 续页流重置节流状态（旧定时器不得占用新页调度槽位；
    // _pendingHasMore 归 null → 无新批次信息时保持 state.hasMore 旧语义）— Qoder UI
    _resultsFlushTimer?.cancel();
    _resultsFlushTimer = null;
    _pendingHasMore = null;
    state = state.copyWith(searchPage: nextPage, isLoading: true, error: null);

    try {
      final stopping = _stopping;
      if (stopping != null) await stopping;
      await session.controlsSettled;
      if (!_ownsSession(session, seq)) return;
      final sourceUrls = await _resolveSearchSources();
      if (!_ownsSession(session, seq)) return;
      if (sourceUrls != null && sourceUrls.isEmpty) {
        state = state.copyWith(error: '所选筛选范围内无有效书源，请调整筛选条件', isLoading: false);
        return;
      }
      await settings.reloadRuntime();
      await settings.settled();
      if (!_ownsSession(session, seq)) return;
      _keepOther = !settings.current.precisionSearch;
      _attachSearchStream(session, keyword, nextPage, sourceUrls, seq);
    } catch (e) {
      if (!_ownsSession(session, seq)) return;
      state = state.copyWith(error: errorMessage(e), isLoading: false);
      unawaited(_invalidateSession());
    }
  }

  /// 订阅逐源流（新搜索 / 续页共用；批次B：page 参数透传 Rust 侧）
  void _attachSearchStream(
    SearchSession session,
    String keyword,
    int page,
    List<String>? sourceUrls,
    int seq,
  ) {
    session.start(
      keyword: keyword,
      page: page,
      sourceUrls: sourceUrls,
      onBatch: (batch) {
        if (!_ownsSession(session, seq)) return;
        // [UI-fix v2.0.11 | 2026-08-10] 消费批次 error（对齐原版 SearchModel：
        // 单源失败静默不弹 UI、仅 AppLog.put 留痕，失败源不阻断整体搜索，
        // 不再产生任何「异常书源」弹窗提示路径）— Reasonix
        final batchError = batch.error;
        if (batchError != null && batchError.isNotEmpty) {
          final srcName = batch.sourceName;
          // 日志写入失败不阻断搜索主流程（对齐原版 AppLog.put 尽力而为语义）
          unawaited(
            Future<void>.sync(
              () => ref
                  .read(appLogRepositoryProvider)
                  // Rust日志使用message/crash/http，非法级别会返回错误。
                  .appLogPush(
                    level: 'message',
                    message: '书源搜索出错\n$srcName: $batchError',
                  ),
            ).catchError((_) {}),
          );
          // [队列④ P1-B] 单源失败不再完全不可见：累积进 failedSources，
          // 由搜索结果页顶部非阻断横幅呈现（文案=批次 error，展开可见
          // 涉及源名）；不改整体搜索交互（失败源不阻断搜索，静默语义保留）
          _recordSourceFailure(srcName, batchError);
        }
        _aggregator.addAll(batch.books);
        // [2026-08-24] 节流重建：批次仅入桶 + 记录待写进度字段，
        // results 列表至多每 150ms 物化一次（排序 O(k log k)，无全量
        // 重聚合），流结束做最终物化 — Qoder UI
        _pendingSearchedCount = batch.finishedCount;
        _pendingTotalCount = batch.totalCount;
        final hasMoreField = batch.hasMore;
        if (hasMoreField != null) _pendingHasMore = hasMoreField;
        _scheduleResultsFlush(seq);
      },
      onError: (Object e) {
        if (!_ownsSession(session, seq)) return;
        _resultsFlushTimer?.cancel();
        _resultsFlushTimer = null;
        _flushResults();
        state = state.copyWith(
          error: errorMessage(e),
          isLoading: false,
          isPaused: false,
        );
        unawaited(_invalidateSession());
      },
      onDone: () {
        if (!_ownsSession(session, seq)) return;
        // [2026-08-24] 流结束：取消挂起的节流定时器并做最终全量聚合
        // （保证最后一批结果不丢失于节流窗口）— Qoder UI
        _resultsFlushTimer?.cancel();
        _resultsFlushTimer = null;
        _flushResults();
        // 流结束（含挂起期间已派发任务全部完成）→ 清软挂起态
        state = state.copyWith(isLoading: false, isPaused: false);
      },
    );
    if (_ownsSession(session, seq) && session.requestedPaused) {
      unawaited(pauseSearch());
    }
  }

  /// 记录单源搜索失败（队列④ P1-B：批次 error 通道 → 可见状态累积）
  ///
  /// 同会话内同源去重（最新错误优先），防跨页重试导致列表无界增长；
  /// 每次失败立即回写 state（横幅即时可见，不经结果列表 150ms 节流窗口）。
  /// 调用方（批次回调）已做 `_searchSeq` 守卫，旧搜索的迟到批次不会误写。
  void _recordSourceFailure(String sourceName, String error) {
    final updated = <SearchSourceFailure>[
      for (final f in state.failedSources)
        if (f.sourceName != sourceName) f,
      SearchSourceFailure(sourceName: sourceName, error: error),
    ];
    state = state.copyWith(failedSources: updated);
  }

  /// 节流调度结果列表物化（2026-08-24：修复逐批次全量重聚合 + 全量替换
  /// 导致的搜索卡顿；对齐原版增量渲染语义）
  ///
  /// 逐源批次仅入桶并记录待写进度字段；至多每 [_flushInterval] 触发一次
  /// 排序物化 + state 回写（无全量重聚合），流结束时由 onDone 做最终物化。
  /// seq 守卫使旧搜索的挂起定时器失效。
  void _scheduleResultsFlush(int seq) {
    if (_resultsFlushTimer != null) return; // 已有挂起调度，复用
    _resultsFlushTimer = Timer(_flushInterval, () {
      _resultsFlushTimer = null;
      if (_isCurrent(seq)) _flushResults();
    });
  }

  /// 将物化列表 + 待写进度字段回写 state（节流窗口内至多一次排序物化）— Qoder UI
  void _flushResults() {
    state = state.copyWith(
      results: _aggregator.snapshot(keepOther: _keepOther),
      searchedCount: _pendingSearchedCount,
      totalCount: _pendingTotalCount,
      // G-B-02：消费批次 has_more（Rust 侧当前页非空批次的累积 OR）；
      // 无新批次信息时保持 state.hasMore
      hasMore: _pendingHasMore ?? state.hasMore,
    );
  }

  bool _ownsLifecycle(int lifecycle) =>
      !_disposed && ref.mounted && lifecycle == _lifecycleGeneration;

  bool _isCurrent(int seq) => !_disposed && ref.mounted && seq == _searchSeq;

  bool _ownsSession(SearchSession session, int seq) =>
      _isCurrent(seq) && identical(_session, session);

  /// 同步隔离旧回调；清理失败留痕，不把旧取消送到后来的执行实例。
  Future<void> _invalidateSession() {
    _searchSeq++;
    _resultsFlushTimer?.cancel();
    _resultsFlushTimer = null;
    final session = _session;
    _session = null;
    final previous = _stopping;
    if (session == null) return previous ?? Future<void>.value();
    final closing = session.close().catchError((Object error) {
      debugPrint('搜索会话清理失败: $error');
    });
    final stopping = Future.wait<void>([?previous, closing]).then<void>((_) {});
    _stopping = stopping;
    unawaited(
      stopping.then((_) {
        if (identical(_stopping, stopping)) _stopping = null;
      }),
    );
    return stopping;
  }

  /// 停止时先发布已出结果，再关闭当前会话；迟到完成不回写新查询。
  Future<void> stop() async {
    if (_disposed || !state.isLoading) return;
    _resultsFlushTimer?.cancel();
    _resultsFlushTimer = null;
    _flushResults();
    final stopping = _invalidateSession();
    state = state.copyWith(
      isLoading: false,
      isManualStop: true,
      isPaused: false,
    );
    await stopping;
  }

  /// 页面销毁期间延迟展示回写，但不让旧页面的停止影响新查询。
  void stopOnPageExit() {
    final seq = _searchSeq;
    Future.microtask(() {
      if (_isCurrent(seq)) unawaited(stop());
    });
  }

  /// 原生只软暂停未派发任务，等待完成后才回写当前会话。
  Future<void> pauseSearch() async {
    if (_disposed || !state.isLoading) return;
    final session = _session;
    if (session == null) return;
    final seq = _searchSeq;
    try {
      final applied = await session.setPaused(true);
      if (applied && _ownsSession(session, seq)) {
        state = state.copyWith(isPaused: true);
      }
    } catch (e) {
      debugPrint('暂停搜索失败: $e');
    }
  }

  /// 在途暂停也接受恢复，控制由会话串行，失败保持已确认的状态。
  Future<void> resumeSearch() async {
    if (_disposed) return;
    final session = _session;
    if (session == null || (!state.isPaused && !session.requestedPaused)) {
      return;
    }
    final seq = _searchSeq;
    try {
      final applied = await session.setPaused(false);
      if (applied && _ownsSession(session, seq)) {
        state = state.copyWith(isPaused: false);
      }
    } catch (e) {
      debugPrint('恢复搜索失败: $e');
    }
  }

  /// 解析搜索范围：将分组和书源选择合并为最终的 sourceUrls 列表
  /// 返回 null 表示搜索全部书源
  Future<List<String>?> _resolveSearchSources() async {
    // 无任何筛选条件时搜索全部
    if (state.selectedSourceUrls.isEmpty && state.selectedGroups.isEmpty) {
      debugPrint('搜索范围: 全部书源（无筛选）');
      return null;
    }

    final urls = <String>{...state.selectedSourceUrls};
    final groups = {...state.selectedGroups};

    // 将选中的分组解析为对应的书源 URL
    if (groups.isNotEmpty) {
      try {
        final allSources = await ref
            .read(bookSourceRepositoryProvider)
            .getEnabledBookSources();
        for (final source in allSources) {
          final group = source.bookSourceGroup;
          if (group != null && group.isNotEmpty) {
            // 书源分组可能包含多个组名（对标原版 AppPattern.splitGroupRegex）
            final sourceGroups = group
                .split(_splitGroupRegex)
                .map((g) => g.trim());
            if (sourceGroups.any(groups.contains)) {
              urls.add(source.bookSourceUrl);
            }
          }
        }
      } catch (e) {
        // 分组解析失败时仅使用直接选中的书源
        // [审计修复 §4.1] debugPrint 留痕 — Qoder
        debugPrint('书源分组解析失败: $e');
      }
    }

    debugPrint(
      '搜索范围: groups=$groups sourceUrls=${urls.length} '
      '(selectedUrls=${state.selectedSourceUrls.length})',
    );
    // 有筛选条件但解析结果为空，返回空列表（而非 null）以区分"搜索全部"
    return urls.toList();
  }

  /// 从 AppConfig 恢复搜索范围（对齐原版 SearchScope / searchScope 持久化）
  Future<void> _restoreSearchScope(int scopeRevision) async {
    final lifecycle = _lifecycleGeneration;
    if (!_ownsLifecycle(lifecycle)) return;
    try {
      final repository = ref.read(searchSettingsRepositoryProvider);
      await repository.loadRuntime();
      final settings = repository.current;
      final scope = settings.scope;
      if (!_ownsLifecycle(lifecycle) || scopeRevision != _scopeRevision) return;
      if (scope.isEmpty) return;
      // 单书源格式 name::url —— 原版不持久化到下次，此处忽略
      if (scope.contains('::')) return;
      final groups = scope
          .split(',')
          .map((g) => g.trim())
          .where((g) => g.isNotEmpty)
          .toSet();
      if (groups.isEmpty) return;
      state = state.copyWith(selectedGroups: groups, selectedSourceUrls: {});
      debugPrint('已恢复搜索范围分组: $groups');
    } catch (e) {
      debugPrint('恢复搜索范围失败: $e');
    }
  }

  /// 持久化搜索范围（对齐原版 SearchScope.save → AppConfig.searchScope/searchGroup）
  Future<void> _persistSearchScope() async {
    _scopeRevision++;
    try {
      final groups = state.selectedGroups.toList()..sort();
      final urls = state.selectedSourceUrls;
      String scope;
      String searchGroup;
      if (groups.isEmpty && urls.isEmpty) {
        scope = '';
        searchGroup = '';
      } else if (groups.isEmpty && urls.length == 1) {
        // 单书源不写入 searchGroup（对齐原版 isSource 不缓存为分组）
        final url = urls.first;
        scope = '::$url';
        searchGroup = '';
      } else if (groups.isNotEmpty && urls.isEmpty) {
        scope = groups.join(',');
        searchGroup = groups.length == 1 ? groups.first : '';
      } else {
        // 混合多选：以分组为主写入 scope；searchGroup 仅单分组时有值
        scope = groups.isNotEmpty ? groups.join(',') : '';
        searchGroup = groups.length == 1 ? groups.first : '';
      }
      await ref
          .read(searchSettingsRepositoryProvider)
          .update(
            (current) =>
                current.copyWith(scope: scope, searchGroup: searchGroup),
          );
    } catch (e) {
      debugPrint('持久化搜索范围失败: $e');
    }
  }

  /// 清空关键词与结果（同时取消进行中的搜索）
  void clearResults() {
    if (_disposed) return;
    unawaited(_invalidateSession());
    _pendingHasMore = null;
    _pendingSearchedCount = 0;
    _pendingTotalCount = 0;
    // 批次B：会话级增量桶与分页态随清空重置
    _aggregator.reset();
    state = state.copyWith(
      keyword: '',
      results: [],
      error: null,
      isLoading: false,
      searchedCount: 0,
      totalCount: 0,
      searchPage: 1,
      hasMore: false,
      isPaused: false,
      isManualStop: false,
      // [队列④ P1-B] 清空结果 → 失败源横幅一并清空
      failedSources: const [],
    );
  }

  /// 打开搜索页时重置为默认态（对齐原版：每次打开 = 新 ViewModel）
  ///
  /// 原版 SearchActivity 每次打开新建 SearchViewModel：results/searchKey 空、
  /// **不自动执行上次搜索**，仅显示搜索框 + 历史建议；
  /// Flutter 侧 notifier 为全局单例，若不重置则重开页面默认残留上次结果。
  /// 历史与筛选范围保留（原版历史读 DB、searchScope 经 AppConfig 持久化）。
  void resetForOpen() {
    if (_disposed) return;
    unawaited(_invalidateSession());
    _pendingHasMore = null;
    _pendingSearchedCount = 0;
    _pendingTotalCount = 0;
    // 批次B：会话级增量桶与分页态随页面重开重置（新 ViewModel 语义）
    _aggregator.reset();
    state = state.copyWith(
      keyword: '',
      inputText: '',
      results: [],
      error: null,
      isLoading: false,
      searchedCount: 0,
      totalCount: 0,
      searchPage: 1,
      hasMore: false,
      isPaused: false,
      isManualStop: false,
      // [队列④ P1-B] 页面重开（新 ViewModel 语义）→ 失败源横幅一并清空
      failedSources: const [],
    );
  }

  // ===== 书源筛选 =====

  /// 切换书源选中状态（单选：对齐原版 SearchScopeDialog rb_source + RadioButton）
  void toggleSource(String sourceUrl) {
    if (state.selectedSourceUrls.contains(sourceUrl)) {
      state = state.copyWith(selectedSourceUrls: {});
    } else {
      state = state.copyWith(
        selectedSourceUrls: {sourceUrl},
        selectedGroups: {},
      );
    }
    unawaited(_persistSearchScope());
  }

  /// 弹层确认或路由指定时一次应用书源集合，不发布部分选择的中间态。— Codex + UI
  void setSources(Iterable<String> sourceUrls) {
    state = state.copyWith(
      selectedSourceUrls: {...sourceUrls},
      selectedGroups: {},
    );
    unawaited(_persistSearchScope());
  }

  /// 清除书源筛选
  void clearSourceFilter() {
    state = state.copyWith(selectedSourceUrls: {});
    unawaited(_persistSearchScope());
  }

  // ===== 分组筛选 =====

  /// 切换分组选中状态（多选累加；菜单单选请用 [selectGroupExclusive]）
  void toggleGroup(String group) {
    final next = {...state.selectedGroups};
    if (next.contains(group)) {
      next.remove(group);
    } else {
      next.add(group);
    }
    state = state.copyWith(selectedGroups: next);
    unawaited(_persistSearchScope());
  }

  /// 单选替换分组（对齐原版 menu_group_2 → SearchScope.update(title)）
  ///
  /// 原子写入 selectedGroups={group} 并清空书源多选，避免 clear+toggle 两步
  /// 中间态被并发 search 读到空分组而回退全量源（分组粘性根因之一）。
  void selectGroupExclusive(String group) {
    state = state.copyWith(selectedGroups: {group}, selectedSourceUrls: {});
    unawaited(_persistSearchScope());
  }

  /// 批量设置分组选择（对齐原版 SearchScopeDialog rb_group CheckBox「确定」）
  ///
  /// 原子写入 selectedGroups 并清空书源筛选，避免多次 toggleGroup
  /// 的中间态被并发 search 读到（与 [selectGroupExclusive] 同根因防护）。
  void setGroups(List<String> groups) {
    state = state.copyWith(selectedGroups: {...groups}, selectedSourceUrls: {});
    unawaited(_persistSearchScope());
  }

  /// 清除分组筛选
  void clearGroupFilter() {
    state = state.copyWith(selectedGroups: {});
    unawaited(_persistSearchScope());
  }

  /// 清除所有筛选（分组 + 书源）
  void clearAllFilter() {
    state = state.copyWith(selectedSourceUrls: {}, selectedGroups: {});
    unawaited(_persistSearchScope());
  }

  /// 清除错误状态
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// 搜索页 Notifier 全局 Provider
///
/// 使用方式：
/// ```dart
/// final state = ref.watch(searchNotifierProvider);
/// ref.read(searchNotifierProvider.notifier).search('关键词');
/// ```
final searchNotifierProvider = NotifierProvider<SearchNotifier, SearchState>(
  SearchNotifier.new,
);
