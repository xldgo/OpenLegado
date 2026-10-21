import '../../app/routing/app_navigation.dart';
import '../../widgets/app_content_transition.dart';
import '../../app/routing/route_names.dart';
import '../book_sources/book_source_repository_provider.dart';
import '../../widgets/app_menu.dart';

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../widgets/app_scaffold.dart';
import '../../widgets/legado_app_bar.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../../l10n/app_localization.dart';
import '../../models/models.dart';
import '../../domain/models/search_settings.dart';
import '../bookshelf/bookshelf.dart';
import 'search_notifier.dart';
import 'search_settings_provider.dart';

import '../../widgets/book_cover.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/skeleton.dart'; // [LAYOUT_PLAN P4] 首屏 Skeleton 接线
import '../../widgets/app_animated_text_line.dart';
part 'search_screen_helpers.part.dart';
part 'search_screen_builders.part.dart';
part 'search_screen_scope_sheet.part.dart';

// ↑ 分域 part 文件（体检 §三.16 超长文件拆分）：非生命周期方法按域拆入 extension，
// 零行为变更（同 library 私有成员可访问）。

/// 书源分组拆分正则（对标原版 AppPattern.splitGroupRegex：[,;，；]）
final _splitGroupRegex = RegExp(r'[,;，；]');

/// 搜索页面
///
/// 状态由 [SearchNotifier]（Riverpod）管理；加书架过渡期仍用 BookshelfProvider。
class SearchScreen extends ConsumerStatefulWidget {
  /// 初始搜索词（对齐原版 SearchActivity.start(context, query)）
  final String? initialQuery;

  /// 预选书源 URL 列表（对齐原版 SearchActivity.start(context, bookSource)：
  /// 从发现页「搜索」菜单进入时按指定书源搜索）— 发现页修复 R2
  final List<String>? initialSourceUrls;

  /// 预选分组列表（对齐原版 receiptIntent searchScope）
  final List<String>? initialGroups;

  const SearchScreen({
    super.key,
    this.initialQuery,
    this.initialSourceUrls,
    this.initialGroups,
  });

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen>
    with WidgetsBindingObserver {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  final _resultsScrollController = ScrollController();
  ScrollController? _scrollTopController;
  // [fix v2.0.102] 构造期捕获 notifier 实例：riverpod 在 state.dispose() 执行前
  // 已将 element 标记为 disposed，dispose 内任何 ref.read 都会抛
  // 「Cannot use ref after the widget was disposed」；state getter 为 protected，
  // 故另存最近一次 build 的 state 供 dispose 判断 isLoading — Qoder UI
  late final SearchNotifier _searchNotifier;
  SearchState? _lastBuiltState;
  // 精准搜索开关（对标原版 menu_precision_search，展示层精确书名过滤）
  bool get _precision =>
      ref.read(searchSettingsRepositoryProvider).current.precisionSearch;
  // 标识读过的书籍（对标原版 AppConfig.showSearchReadRecord）
  bool get _showReadRecord =>
      ref.read(searchSettingsRepositoryProvider).current.showReadRecord;
  // [A1 形态对齐 | full-stack-engineer + UI] 搜索结果过滤屏蔽词（对标原版
  // PreferKey.searchResultFilter：每行一个普通文本，匹配书名/作者/分类标签，
  // 忽略英文大小写）。空串 = 过滤关闭；非空 = 过滤开启（顶栏主题色图标）。
  String get _resultFilter =>
      ref.read(searchSettingsRepositoryProvider).current.resultFilter;
  // 输入帮助层显隐（对标原版 ll_input_help / setOnQueryTextFocusChangeListener）
  bool _showInputHelp = true;
  // 空结果智能引导弹窗：每次搜索最多弹一次
  int _searchSessionId = 0;
  int _emptyDialogShownForSession = -1;
  // [UI-fix v2.0.3 | 2026-08-07] 锚定菜单定位键：分组 PopupMenu 锚定按钮下方 — Qoder
  // [1-6 ①] 2.0.259 ⋮ 溢出菜单移除后，该键由 ⚙ 设置弹层 AppMenuButton 复用（锚定 ⚙ 钮下方）
  final _menuButtonKey = GlobalKey();
  // [队列④ P1-B] 失败书源横幅展开态（折叠=摘要行，展开=逐源明细；
  // failedSources 变空时经 ref.listen 自动收起，见 build 内监听回调）
  bool _failedBannerExpanded = false;
  int? _loginToastShownForSession;

  @override
  void initState() {
    super.initState();
    _searchNotifier = ref.read(searchNotifierProvider.notifier);
    // 批次B G-B-04：监听 app 生命周期（原版 repeatOnLifecycle(RESUMED)）
    WidgetsBinding.instance.addObserver(this);
    _focusNode.addListener(_onFocusChanged);
    final initial = widget.initialQuery?.trim();
    if (initial != null && initial.isNotEmpty) {
      _searchController.text = initial;
    }
    // 对齐原版：打开搜索页默认不显示上次结果（新 ViewModel 语义，不 auto-search）。
    // Riverpod 禁止在 widget 生命周期内同步修改 provider，
    // 按官方建议延迟到微任务执行。
    Future.microtask(() {
      if (!mounted) return;
      ref.read(searchNotifierProvider.notifier).resetForOpen();
      // 预选分组（路由 searchScope / groups 参数）
      final groups = widget.initialGroups;
      if (groups != null && groups.isNotEmpty) {
        for (final group in groups) {
          ref.read(searchNotifierProvider.notifier).toggleGroup(group);
        }
      }
      // 预选书源（发现页「搜索」入口指定书源，单选取首个）
      final sourceUrls = widget.initialSourceUrls;
      if (sourceUrls != null && sourceUrls.isNotEmpty) {
        ref
            .read(searchNotifierProvider.notifier)
            .toggleSource(sourceUrls.first);
      }
      final q = widget.initialQuery?.trim();
      if (q != null && q.isNotEmpty) {
        ref.read(searchNotifierProvider.notifier).setInput(q);
        ref.read(searchNotifierProvider.notifier).search(q);
      }
    });
  }

  /// UI 只提交差量并展示保存错误；回退状态由同一设置快照通知。
  Future<void> _updateSearchSettings(
    SearchSettings Function(SearchSettings) transform,
  ) async {
    try {
      await ref.read(searchSettingsRepositoryProvider).update(transform);
    } catch (error, stackTrace) {
      debugPrint('保存搜索设置失败: $error\n$stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('搜索设置保存失败，请重试')));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // 对齐原版 SearchActivity 销毁 → scope.cancel()：离开页面取消进行中的搜索，
    // 避免 Rust 侧流在后台继续消耗资源（批次B G-B-04 配套）— Cursor UI
    // [fix v2.0.102] dispose 内不可用 ref（riverpod unmount 时序），改用捕获实例 — Qoder UI
    // [fix v2.0.102] stop() 会同步写 provider 状态，触发 build 中注册的 ref.listen
    // 监听器（_updateInputHelpVisibility → ref.read）；unmount 期间 element 已
    // deactivate（context.mounted=false）→ "Cannot use ref after disposed"。
    // 故经 microtask 延迟到 unmount 全部完成后执行：此时 riverpod 已关闭本
    // element 的 listen 订阅，状态回写不再回调任何 UI 监听器。— Qoder UI
    final shouldStop = _lastBuiltState?.isLoading ?? false;
    _focusNode.removeListener(_onFocusChanged);
    _searchController.dispose();
    _focusNode.dispose();
    _resultsScrollController.dispose();
    super.dispose();
    if (shouldStop) {
      _searchNotifier.stopOnPageExit();
    }
  }

  /// app 退后台软挂起 / 回前台恢复（批次B G-B-04：对齐原版
  /// repeatOnLifecycle(RESUMED) → viewModel.pause()/resume()）— Cursor UI
  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    final state = ref.read(searchNotifierProvider);
    final notifier = ref.read(searchNotifierProvider.notifier);
    if (lifecycleState == AppLifecycleState.paused &&
        state.isLoading &&
        !state.isPaused) {
      unawaited(notifier.pauseSearch());
    } else if (lifecycleState == AppLifecycleState.resumed && state.isLoading) {
      unawaited(notifier.resumeSearch());
    }
  }

  @override
  Widget build(BuildContext context) {
    // 只订阅变化触发绘制，字段始终读取 Repository 当前快照。
    ref.watch(searchSettingsProvider);
    ref.listen(searchSettingsProvider, (_, next) {
      if (next case AsyncError(:final error, :final stackTrace)) {
        debugPrint('恢复搜索设置失败: $error\n$stackTrace');
      }
    });
    final state = ref.watch(searchNotifierProvider);
    _lastBuiltState = state;

    ref.listen<SearchState>(searchNotifierProvider, (prev, next) {
      if (prev == null) return;
      // [队列④ P1-B] 失败书源横幅自动收起：failedSources 由非空变空
      // （新关键词搜索 / 清空 / 页面重开三处重置）时复位展开态，
      // 避免横幅消失后展开标志残留导致下次搜索横幅默认展开
      if (prev.failedSources.isNotEmpty &&
          next.failedSources.isEmpty &&
          mounted) {
        setState(() => _failedBannerExpanded = false);
      }
      // 新搜索开始：重置空结果弹窗计数
      if (!prev.isLoading && next.isLoading) {
        _searchSessionId++;
      }
      // 新搜索开始时滚顶（对齐原版 AdapterDataObserver.onItemRangeInserted：
      // 仅当条目插入于 positionStart == 0 —— 即新关键词结果重置重填时滚顶；
      // 流式增量批次与续页追加的 positionStart > 0，不触发）。
      // [2026-08-24] 旧条件在加载中任何长度变化都滚顶：节流增量渲染每 150ms flush
      // 都会 animateTo(0) → 页面被反复拉回顶部、无法滚动。改为仅在「新搜索开始」
      // （isLoading false→true 且关键词变化或结果已清空）时触发。— Qoder UI
      final isNewSearch =
          !prev.isLoading &&
          next.isLoading &&
          (prev.keyword != next.keyword || next.results.isEmpty);
      if (isNewSearch) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final controller = _scrollTopController;
          if (mounted && controller != null && controller.hasClients) {
            controller.animateTo(
              0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        });
      }
      _updateInputHelpVisibility();
      // [结果可见性兜底 | 2026-09-26] 搜索完成且有结果时收起焦点：输入帮助层
      // 显隐口径为「聚焦即帮助层」（对标原版 setOnQueryTextFocusChangeListener），
      // 手机上键盘与焦点同起同落不构成困局；桌面/模拟器 IME 可能键盘已收而
      // 焦点仍在 → 帮助层常驻盖住结果且无键盘可收（真机验收实测 2026-09-26）。
      // 完成即失焦，结果必然可见；用户重新聚焦仍可唤出帮助层（设计不变）。
      if (prev.isLoading &&
          !next.isLoading &&
          next.hasResults &&
          _focusNode.hasFocus) {
        _focusNode.unfocus();
      }
      // [登录提示 | 2026-09-26] 参考版行为：搜索完成后有「需要登录」类失败
      // 时底部弹出一次轻提示（用户描述：底下会弹出一下提示）。按会话去重，
      // 不随批次重复打扰；具体源清单仍在失败横幅（可展开/复制）。
      if (prev.isLoading &&
          !next.isLoading &&
          next.failedSources.isNotEmpty &&
          _loginToastShownForSession != _searchSessionId) {
        final loginCount = next.failedSources
            .where(
              (f) =>
                  f.error.contains('Login required') ||
                  f.error.contains('需要登录'),
            )
            .length;
        if (loginCount > 0 && mounted) {
          _loginToastShownForSession = _searchSessionId;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.searchLoginRequiredCount(loginCount)),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
      // 空结果智能引导（对齐原版 searchFinishLiveData L457-477）
      if (prev.isLoading &&
          !next.isLoading &&
          next.isEmpty &&
          next.hasFilter &&
          _emptyDialogShownForSession != _searchSessionId) {
        _emptyDialogShownForSession = _searchSessionId;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showEmptyScopeDialog(next);
        });
      }
    });

    return PopScope(
      // 对标原版 finish()：搜索框聚焦时返回仅失焦不退出
      canPop: !_focusNode.hasFocus,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _focusNode.hasFocus) {
          FocusScope.of(context).unfocus();
        }
      },
      child: AppScaffold(
        topBar: _buildAppBar(context),
        body: AppScrollBody(
          controller: _resultsScrollController,
          builder: (context, scrollController) {
            // 新搜索回到整体顶部，增量结果继续沿用内层滚动位置。— Codex + UI
            _scrollTopController =
                context
                    .findAncestorStateOfType<NestedScrollViewState>()
                    ?.outerController ??
                scrollController;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 顶部进度条（对齐原版 refresh_progress_bar，2dp）
                if (state.isLoading && state.totalCount > 0)
                  LinearProgressIndicator(
                    value: state.searchedCount / state.totalCount,
                    minHeight: 2,
                  ),
                // [UI_SYNC_REFACTOR S5 修 | 2026-09-08] 结果/进度胶囊（对齐参考版
                // 「结果 N · 进度 X/Y」）：多源搜索的实时反馈，搜索后常驻 — Qoder
                if (state.totalCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          context.l10n.searchProgressSummary(
                            state.results.length,
                            state.searchedCount,
                            state.totalCount,
                          ),
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                    ),
                  ),
                // [队列④ P1-B] 失败书源横幅（列表头位置，非阻断、可滚动）：
                // 单源搜索失败原仅 AppLog 留痕，现按批次 error 文案呈现，
                // 展开可见涉及源名；不改整体搜索交互（失败源不阻断搜索）
                if (state.failedSources.isNotEmpty)
                  _buildFailedSourcesBanner(
                    context,
                    state.failedSources,
                    _failedBannerExpanded,
                  ),
                Expanded(
                  child: _buildSceneBody(context, state, scrollController),
                ),
              ],
            );
          },
        ),
        // 批次B G-B-02：搜索中=stop；空闲且 hasMore=play（原版 fb_start_stop + searchFinally）
        floatingActionButton: state.isLoading
            ? _buildStopFab(context, state)
            : (state.hasMore &&
                  !state.isManualStop &&
                  state.error == null &&
                  state.keyword.isNotEmpty)
            ? _buildNextPageFab()
            : null,
      ),
    );
  }
}
