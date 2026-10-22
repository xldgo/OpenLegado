import '../../../app/routing/app_navigation.dart';
import '../application/reader_pagination_policy.dart';
import '../../../providers/chapter_content_provider.dart';
import '../../../platform/display/battery_level_monitor.dart';
import '../../../domain/models/read_aloud_content.dart';

import '../application/reader_settings_provider.dart';

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../../../l10n/app_strings.dart';
import '../../../models/models.dart';
import '../application/reader_notifier.dart';
import '../../audio/application/audio_notifier.dart';
import '../../audio/application/read_aloud_preferences.dart';
import '../../../app/routing/route_names.dart';
import '../../../widgets/error_view.dart';
import '../../../widgets/loading_indicator.dart';
import '../layout/paragraph_layout_engine.dart';
import 'reader_page_chrome.dart';
import '../layout/reader_title_layout.dart';
import '../turn/page_direction.dart';
import '../turn/reader_turn_view.dart';
import 'reader_text_content.dart';
import '../selection/reader_selection_controller.dart';
import '../selection/reader_selection_region.dart';
import '../layout/text_layout_environment.dart';
import 'review_column.dart';
import '../layout/chapter_pagination_session.dart';
import '../layout/reader_footer_geometry.dart';
import '../../../platform/display/display_corners.dart';

import 'package:flutter/scheduler.dart';

/// 阅读器内容区（分页 + 5 种翻页模式）
///
/// 对齐安卓原版 ReadView + 5 种 PageDelegate（覆盖/滑动/仿真/滚动/无动画）。
/// 拥有排版分页状态与 PageController，通过 [ReaderPageViewState] 对外暴露
/// 翻页导航方法（供自动翻页/点击区域调用）。
class ReaderPageView extends ConsumerStatefulWidget {
  /// 段落间距（来自高级配置）
  final double paragraphSpacing;

  // [UI-fix v2.0.2 | 2026-08-06] 阅读配置面板新增参数接入排版：
  // 字距调节/首行缩进/两端对齐（MoreConfig） — Qoder

  /// 字距（em 语义，对标原版 ReadBookConfig.letterSpacing；渲染/测量时
  /// 乘以字号换算为 px，[UI-fix v2.0.4 | 2026-08-08] — Qoder）
  final double letterSpacing;

  /// 首行缩进字符数（0-3，对标原版 paragraphIndent 缩进档位；
  /// [UI-fix v2.0.4 | 2026-08-08] 由 bool 升级为 int 档位）
  final int paragraphIndent;

  /// 两端对齐开关（对标 MoreConfig textFullJustify）
  final bool textFullJustify;
  final bool textBottomJustify;

  // [UI-fix v2.0.3 | 2026-08-06] 页面边距四向可调（对标原版
  // ReadBookConfig paddingTop/Bottom/Left/Right） — Qoder
  final double marginTop;
  final double marginBottom;
  final double marginLeft;
  final double marginRight;

  /// 页眉/页脚提示与标题样式（对标 ReadView PageView）
  final ReaderPageChromeConfig pageChrome;

  /// 页面内部的系统栏/屏幕缺口避让；翻页画布保持完整视口。
  final EdgeInsets? contentInsets;

  // [UI-fix v2.0.3 | 2026-08-08] MoreConfig 第①批消费点 — Qoder

  /// 长按选择文本开关（对标原版 selectText，关闭后长按不弹选区面板）
  final bool selectText;

  /// 选区内部的普通点按仍交给阅读九宫格，避免原生选区吞掉菜单点按。
  final ValueChanged<TapUpDetails>? onTapUp;

  /// 滚动翻页无动画（对标原版 noAnimScrollPage：程序化翻页去除动画）
  final bool noAnimScroll;

  // [UI-fix v2.0.4 | 2026-08-08] 界面面板/MoreConfig 第②批消费点 — Qoder

  /// 文字字重（0中/1粗/2细，对标原版 textBold）
  final int textBold;

  /// [C3 斜体 | Qoder UI] 正文斜体（参考版行内字体面板「斜体」开关；
  /// 与 textBold 同链路：参与分页测量与渲染，保持同源同参）
  final bool italic;

  /// 鼠标滚轮翻页（对标原版 mouseWheelPage；分页模式下滚轮上下滚动翻页，
  /// 滚动模式不拦截交给内层 Scrollable）
  final bool mouseWheelPage;

  // [UI-fix v2.0.5 | 2026-08-10] 双页模式接入（对标原版 doubleHorizontalPage
  // 0-3 档：0=单页、1=双页、2=横屏双页、3=平板或横屏双页；滚动模式强制单页）
  /// 双页模式档位（0-3）
  final int doubleHorizontalPage;

  /// 中文分行开关：开启时使用中文断行核心，关闭时按簇宽断行。
  /// 自定义中文分行开关
  final bool useZhLayout;

  // [UI-fix v2.0.5 | 2026-08-10] 段首标点悬挂（对标原版 hangingPunctuation）— Reasonix
  /// 段首标点悬挂开关
  final bool hangingPunctuation;

  /// 段评摘要 counts（P2-9）
  final Map<int, int>? reviewCounts;

  /// 段评角标点击
  final ReviewTapCallback? onReviewTap;

  const ReaderPageView({
    super.key,
    required this.paragraphSpacing,
    this.letterSpacing = 0.1,
    this.paragraphIndent = 2,
    this.textFullJustify = true,
    this.textBottomJustify = true,
    this.marginTop = 6,
    this.marginBottom = 6,
    this.marginLeft = 16,
    this.marginRight = 16,
    this.pageChrome = const ReaderPageChromeConfig(),
    this.contentInsets,
    this.selectText = true,
    this.onTapUp,
    this.noAnimScroll = false,
    this.textBold = 0,
    this.italic = false,
    this.mouseWheelPage = true,
    this.doubleHorizontalPage = 0,
    this.useZhLayout = true,
    this.hangingPunctuation = false,
    this.reviewCounts,
    this.onReviewTap,
  });

  @override
  ConsumerState<ReaderPageView> createState() => ReaderPageViewState();
}

class ReaderPageViewState extends ConsumerState<ReaderPageView> {
  late final BatteryLevelMonitor _battery;
  final ReaderSelectionController _selectionController =
      ReaderSelectionController();

  bool consumeSelectionTap() => _selectionController.consumeTap();

  /// 相邻章预载预览页（章边界动画与承接显示；[UI_SYNC_REFACTOR S6 修]）
  Widget? _nextChapterPreview;
  Widget? _prevChapterPreview;
  (PageInfo, int, int, String)? _nextPreviewLayout;
  (PageInfo, int, int, String)? _prevPreviewLayout;
  bool _preloadingNext = false;
  bool _preloadingPrev = false;
  int _layoutGeneration = 0;
  String _reviewPaintKey = '';
  Object? _reviewMeasureKey;
  Map<int, InlineReview> _measuredReviews = {};
  int _paintRevision = 0;
  DisplayCorners? _footerCorners;
  final ChapterLayoutCache _layoutCache = ChapterLayoutCache();
  ChapterPaginationSession? _layoutSession;
  final Set<ChapterPaginationSession> _preloadSessions = {};
  bool _layoutComplete = true;
  bool _waitingForAnchor = false;
  String? _layoutError;
  int _fontRevision = 0;
  bool _fontRefreshRunning = false;
  bool _fontRefreshQueued = false;
  int _layoutMeasurements = 0;
  String? _paginatedBookUrl;

  int get layoutMeasurements => _layoutMeasurements;
  int get layoutCacheHits => _layoutCache.hits;
  bool get layoutComplete => _layoutComplete;

  /// 最近一次分页参数（相邻章预载复用同参；翻页回调触发预载时也需读取）
  ParagraphConfig? _pagedConfig;
  double _pagedParagraphSpacingPx = 0;
  // ignore: prefer_final_fields
  double _pagedWidth = 0;
  // ignore: prefer_final_fields
  double _pagedHeight = 0;

  /// 重构版翻页视图状态（程序化动画翻页入口）
  final GlobalKey<ReaderTurnViewState> _turnViewKey =
      GlobalKey<ReaderTurnViewState>();

  /// [UI-fix v2.0.3 | 2026-08-08] 滚动模式控制器（支撑滚动模式下的
  //  程序化翻页：点击区域/自动翻页/无动画翻页均按屏滚动）— Qoder
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _scrollBodyKey = GlobalKey();
  PageInfo? _scrollLayout;
  List<(double, int, int)> _scrollLinePositions = [];
  bool _restoringScroll = false;
  late final AudioNotifier _audio;
  bool _aloudFramePending = false;
  int? _speechChapterTarget;
  (String, int, int, int)? _aloudPaintKey;
  int _manualNavigationGeneration = 0;
  bool _aloudScrolling = false;
  bool _manualScrollActive = false;
  bool _manualChapterPending = false;

  (int, int)? get _aloudRange {
    final position = _audio.readAloudPosition.value;
    if (position == null ||
        position.bookUrl != _paginatedBookUrl ||
        position.chapterIndex != _paginatedChapterIndex) {
      return null;
    }
    return (position.paragraphStart, position.paragraphEnd);
  }

  void _scheduleAloudFollow() {
    if (_aloudFramePending || !mounted) return;
    _aloudFramePending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _aloudFramePending = false;
      if (mounted) unawaited(_applyAloudFollow());
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _applyAloudFollow() async {
    final position = _audio.readAloudPosition.value;
    final state = ref.read(readerNotifierProvider);
    final audioState = ref.read(audioNotifierProvider);
    final matches =
        position != null &&
        position.bookUrl == state.currentBook?.bookUrl &&
        !audioState.isStreamMode &&
        audioState.state != PlayerState.idle;
    final paintKey = matches && position.chapterIndex == _paginatedChapterIndex
        ? (
            position.bookUrl,
            position.chapterIndex,
            position.paragraphStart,
            position.paragraphEnd,
          )
        : null;
    if (paintKey != _aloudPaintKey) {
      setState(() {
        _aloudPaintKey = paintKey;
        _paintRevision++;
      });
    }
    if (!matches || !_audio.followReadAloud.value || _manualScrollActive) {
      return;
    }
    final reader = ref.read(readerNotifierProvider.notifier);
    if (state.currentChapterIndex != position.chapterIndex) {
      if (_speechChapterTarget != null) return;
      _speechChapterTarget = position.chapterIndex;
      try {
        await reader.goToChapter(
          position.chapterIndex,
          sourceOffset: position.offset,
        );
      } finally {
        _speechChapterTarget = null;
        if (mounted) _scheduleAloudFollow();
      }
      return;
    }
    if (state.isLoading ||
        _paginatedBookUrl != position.bookUrl ||
        _paginatedPages.isEmpty ||
        _paginatedChapterIndex != position.chapterIndex ||
        _paginatedContent != state.chapterContent) {
      return;
    }
    final page = pageIndexForSourceOffset(_paginatedPages, position.offset);
    if (!_layoutComplete && position.offset >= _paginatedPages.last.sourceEnd) {
      return;
    }
    if (state.pageTurnMode == PageTurnMode.scroll) {
      if (!_scrollController.hasClients ||
          _scrollLinePositions.isEmpty ||
          _aloudScrolling) {
        return;
      }
      final body = _scrollBodyKey.currentContext?.findRenderObject();
      final viewport = context.findRenderObject();
      if (body is! RenderBox || viewport is! RenderBox) return;
      var lineIndex = 0;
      for (var i = 0; i < _scrollLinePositions.length; i++) {
        if (_scrollLinePositions[i].$2 > position.offset) break;
        lineIndex = i;
      }
      final y =
          body.localToGlobal(Offset(0, _scrollLinePositions[lineIndex].$1)).dy -
          viewport.localToGlobal(Offset.zero).dy;
      final height = _scrollController.position.viewportDimension;
      if (y < height * 0.1 || y > height * 0.8) {
        final target = (_scrollController.offset + y - height * 0.32).clamp(
          _scrollController.position.minScrollExtent,
          _scrollController.position.maxScrollExtent,
        );
        _aloudScrolling = true;
        try {
          if (widget.noAnimScroll || MediaQuery.disableAnimationsOf(context)) {
            _scrollController.jumpTo(target);
          } else {
            await _scrollController.animateTo(
              target,
              duration: const Duration(milliseconds: 520),
              curve: Curves.fastOutSlowIn,
            );
          }
        } finally {
          _aloudScrolling = false;
        }
      }
    } else {
      final visible = _isDoublePage
          ? page ~/ 2 == _currentPageIndex ~/ 2
          : page == _currentPageIndex;
      if (!visible && !_selectionController.value) {
        setState(
          () => _currentPageIndex = _isDoublePage ? page ~/ 2 * 2 : page,
        );
        reader.updatePosition(_currentPageIndex, sourceOffset: position.offset);
      }
    }
  }

  void _manualAloudNavigation() {
    final audioState = ref.read(audioNotifierProvider);
    final state = ref.read(readerNotifierProvider);
    if (audioState.isStreamMode ||
        audioState.state == PlayerState.idle ||
        audioState.bookUrl != state.currentBook?.bookUrl ||
        _speechChapterTarget != null) {
      return;
    }
    _audio.detachReadAloudFollow();
    final generation = ++_manualNavigationGeneration;
    final reminder = ref.read(readAloudPreferencesProvider).detachReminder;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _manualScrollActive ||
          generation != _manualNavigationGeneration) {
        return;
      }
      final live = ref.read(readerNotifierProvider);
      final position = _audio.readAloudPosition.value;
      if (live.isLoading || live.currentBook?.bookUrl != audioState.bookUrl) {
        return;
      }
      if (_paginatedChapterIndex != live.currentChapterIndex) return;
      if (!reminder) {
        unawaited(
          _audio
              .seekToChapterPosition(
                live.currentChapterIndex,
                ref.read(readerNotifierProvider.notifier).currentSourceOffset ??
                    0,
              )
              .then((_) {
                if (mounted && generation == _manualNavigationGeneration) {
                  _audio.restoreReadAloudFollow();
                }
              }),
        );
      } else if (position != null &&
          position.chapterIndex == live.currentChapterIndex &&
          _paginatedPages.isNotEmpty) {
        final page = pageIndexForSourceOffset(_paginatedPages, position.offset);
        final visible = live.pageTurnMode == PageTurnMode.scroll
            ? _visibleScrollContains(position.offset)
            : (_isDoublePage
                  ? page ~/ 2 == _currentPageIndex ~/ 2
                  : page == _currentPageIndex);
        if (visible) _audio.restoreReadAloudFollow();
      }
    });
  }

  void _detachForManualScroll() {
    final audio = ref.read(audioNotifierProvider);
    if (!audio.isStreamMode &&
        audio.state != PlayerState.idle &&
        audio.bookUrl ==
            ref.read(readerNotifierProvider).currentBook?.bookUrl) {
      _audio.detachReadAloudFollow();
    }
  }

  bool _visibleScrollContains(int offset) {
    if (!_scrollController.hasClients) return false;
    final body = _scrollBodyKey.currentContext?.findRenderObject();
    final viewport = context.findRenderObject();
    if (body is! RenderBox || viewport is! RenderBox) return false;
    var y = 0.0;
    for (final line in _scrollLinePositions) {
      if (line.$2 > offset) break;
      y = line.$1;
    }
    final visibleY =
        body.localToGlobal(Offset(0, y)).dy -
        viewport.localToGlobal(Offset.zero).dy;
    return visibleY >= 0 &&
        visibleY < _scrollController.position.viewportDimension;
  }

  // ===== 排版引擎分页状态 =====

  /// 当前章节的排版分页结果
  List<PageInfo> _paginatedPages = [];

  /// 分页对应的章节索引（用于检测章节切换后重新分页）
  int _paginatedChapterIndex = -1;

  ReaderPaginationSignature? _paginationSignature;
  Size? _paginatedScreenSize;
  TextLayoutEnvironment? _paginatedTextEnvironment;
  bool _paginatedDoublePage = false;
  bool get _isDoublePage => _paginatedDoublePage;
  String _paginatedContent = '';

  /// 当前阅读字体 family（与 FontScreen 持久化键 reader_font_family 同步）
  String? _fontFamily;

  /// 当前页索引（屏级分页）
  int _currentPageIndex = 0;

  /// 当前分页数据对应的章节标题（与 _paginatedChapterIndex 同帧写入，
  /// 章节切换加载中冻结渲染时标题与正文保持同章，避免新标题配旧正文）
  String? _paginatedChapterTitle;

  /// 当前页索引
  int get currentPageIndex => _currentPageIndex;

  // [UI-fix v2.0.4 | 2026-08-08] 鼠标滚轮翻页节流时间戳（300ms 防连翻，
  // 对标原版 ReadView 滚轮事件单次翻页语义）— Qoder
  DateTime _lastWheelTurn = DateTime.fromMillisecondsSinceEpoch(0);

  /// 当前章分页总数（进度条「调章内页」行为消费）
  int get pageCount => _paginatedPages.length;

  /// 当前可见页的原文区间，用于阅读定位与回归验证。
  (int, int) get currentSourceRange => _paginatedPages.isEmpty
      ? (0, 0)
      : (
          _paginatedPages[_currentPageIndex].sourceStart,
          _paginatedPages[_currentPageIndex].sourceEnd,
        );

  /// 程序化跳页（进度条拖动/目录跳转等；直设索引=瞬时切换，
  /// 相邻步进翻页走 _turnViewKey.turnByAnim 保持动画）
  void _navigateToPage(int index) {
    setState(() => _currentPageIndex = index);
    ref
        .read(readerNotifierProvider.notifier)
        .updatePosition(
          index,
          sourceOffset: _paginatedPages[index].sourceStart,
        );
    _manualAloudNavigation();
    // 跳页同样驱动相邻章预载
    _maybePreloadAdjacent(ref.read(readerNotifierProvider));
  }

  /// 滚动模式：按一屏高度滚动（前进/后退，动画随 noAnimScrollPage）
  void _scrollByViewport(bool forward) {
    if (!_scrollController.hasClients) return;
    _detachForManualScroll();
    final pos = _scrollController.position;
    if (!pos.hasViewportDimension) return;
    final delta = forward ? pos.viewportDimension : -pos.viewportDimension;
    final target = (pos.pixels + delta).clamp(
      pos.minScrollExtent,
      pos.maxScrollExtent,
    );
    if (widget.noAnimScroll) {
      _scrollController.jumpTo(target);
      _manualAloudNavigation();
    } else {
      _scrollController
          .animateTo(
            target,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          )
          .then((_) {
            if (mounted) _manualAloudNavigation();
          });
    }
  }

  /// 跳转到章内指定页（进度条「调章内页」行为，对标原版
  //  progressBarBehavior=page 时 seek_read_page 调页语义）— Qoder
  void goToPage(int index) {
    if (_paginatedPages.isEmpty) return;
    final target = index.clamp(0, _paginatedPages.length - 1);
    _navigateToPage(target);
  }

  /// 前进（下一页或下一章）
  ///
  /// 跨章节无缝翻页：到达本章最后一页时自动进入下一章第一页。
  void nextPageOrChapter() {
    if (_waitingForAnchor) return;
    if (_selectionController.value) return;
    final notifier = ref.read(readerNotifierProvider.notifier);
    // [UI-fix v2.0.3 | 2026-08-08] 滚动模式下程序化翻页按屏滚动 — Qoder
    if (ref.read(readerNotifierProvider).pageTurnMode == PageTurnMode.scroll) {
      if (_scrollController.hasClients) {
        final pos = _scrollController.position;
        if (pos.hasViewportDimension && pos.pixels >= pos.maxScrollExtent - 1) {
          if (_layoutComplete) notifier.nextChapter();
        } else {
          _scrollByViewport(true);
        }
      } else {
        notifier.nextChapter();
      }
      return;
    }
    // [UI_SYNC_REFACTOR S6 重构] 动画翻页统一走重构版翻页视图：
    // turnByAnim 内部按方向处理页内/跨章（章边界无邻页快照时瞬时填充）
    final turn = _turnViewKey.currentState;
    if (turn != null) {
      unawaited(turn.turnByAnim(PageTurnDirection.next));
      return;
    }
    // 视图未挂载兜底：直设索引/跨章
    final step = _isDoublePage ? 2 : 1;
    if (_currentPageIndex + step < _paginatedPages.length) {
      _navigateToPage(_currentPageIndex + step);
    } else {
      if (_layoutComplete) notifier.nextChapter();
    }
  }

  /// 后退（上一页或上一章）
  ///
  /// 跨章节无缝翻页：到达本章第一页时自动进入上一章最后一页。
  void prevPageOrChapter() {
    if (_selectionController.value) return;
    final notifier = ref.read(readerNotifierProvider.notifier);
    // [UI-fix v2.0.3 | 2026-08-08] 滚动模式下程序化翻页按屏滚动 — Qoder
    if (ref.read(readerNotifierProvider).pageTurnMode == PageTurnMode.scroll) {
      if (_scrollController.hasClients) {
        final pos = _scrollController.position;
        if (pos.hasViewportDimension && pos.pixels <= pos.minScrollExtent + 1) {
          notifier.prevChapter();
        } else {
          _scrollByViewport(false);
        }
      } else {
        notifier.prevChapter();
      }
      return;
    }
    // [UI_SYNC_REFACTOR S6 重构] 同 next：动画翻页统一走重构版翻页视图
    final turn = _turnViewKey.currentState;
    if (turn != null) {
      unawaited(turn.turnByAnim(PageTurnDirection.prev));
      return;
    }
    final step = _isDoublePage ? 2 : 1;
    if (_currentPageIndex - step >= 0) {
      _navigateToPage(_currentPageIndex - step);
    } else {
      notifier.prevChapter();
    }
  }

  @override
  void initState() {
    super.initState();
    // 当前页与所有预览共享同一电量源，生命周期跟随阅读器组件。— Codex + UI
    _battery = BatteryLevelMonitor();
    _audio = ref.read(audioNotifierProvider.notifier);
    _audio.readAloudPosition.addListener(_scheduleAloudFollow);
    _audio.followReadAloud.addListener(_scheduleAloudFollow);
    _scrollController.addListener(_saveScrollAnchor);
    unawaited(_refreshFontFamily());
  }

  /// 字体选择从仓储读取，自定义文件由统一平台入口注册。
  Future<void> _refreshFontFamily() async {
    if (_fontRefreshRunning) {
      _fontRefreshQueued = true;
      return;
    }
    _fontRefreshRunning = true;
    try {
      await _loadFontFamily();
    } finally {
      _fontRefreshRunning = false;
      if (_fontRefreshQueued && mounted) {
        _fontRefreshQueued = false;
        unawaited(_refreshFontFamily());
      }
    }
  }

  Future<void> _loadFontFamily() async {
    try {
      final settings = await ref.read(readerSettingsRepositoryProvider).load();
      if (!mounted) return;
      final revision = await ref
          .read(readerFontServiceProvider)
          .loadSelected(settings);
      if (!mounted) return;
      if (settings.fontFamily != _fontFamily || revision != _fontRevision) {
        setState(() {
          _fontFamily = settings.fontFamily;
          _fontRevision = revision;
          _paginationSignature = null;
        });
      }
    } catch (error) {
      debugPrint('阅读字体加载失败：$error');
    }
  }

  @override
  void dispose() {
    _battery.dispose();
    _layoutSession?.cancel();
    for (final session in _preloadSessions) {
      session.cancel();
    }
    _layoutCache.clear();
    _selectionController.dispose();
    _audio.readAloudPosition.removeListener(_scheduleAloudFollow);
    _audio.followReadAloud.removeListener(_scheduleAloudFollow);
    _scrollController.dispose();
    super.dispose();
  }

  /// 检查是否需要重新分页（章节/字号/行高/段距变化时触发）
  ///
  /// 移植自安卓端 TextChapterLayout 的排版触发时机：
  /// 章节加载完成、字体设置变更、屏幕尺寸变化
  void _paginateIfNeeded(
    BuildContext context,
    ReaderState state,
    Size viewportSize,
  ) {
    final content = state.chapterContent;
    final fontSize = state.fontSize;
    final lineHeight = state.lineHeight;
    final spacing = widget.paragraphSpacing;
    final chapterIndex = state.currentChapterIndex;
    // [UI-fix v2.0.2 | 2026-08-06] 字距/首行缩进/两端对齐/字体变化同样触发重新分页 — Qoder
    // [UI-fix v2.0.4 | 2026-08-08] 字距 em → px（×字号）；缩进改档位；
    // 字重变化同样触发重新分页（测量与渲染同参保证分页一致）— Qoder
    final letterSpacing = widget.letterSpacing * fontSize;
    final indent = widget.paragraphIndent;
    final textBold = widget.textBold;
    final italic = widget.italic;
    final justify = widget.textFullJustify;
    final fontFamily = _fontFamily;
    // [UI-fix v2.0.3 | 2026-08-06] 页面边距变化同样触发重新分页 — Qoder
    final margins = EdgeInsets.fromLTRB(
      widget.marginLeft,
      widget.marginTop,
      widget.marginRight,
      widget.marginBottom,
    );
    final insets = _contentInsets(context);
    // 翻页画布使用完整视口，测量只使用内部避让后的内容区。
    final screenSize = ReaderPaginationPolicy.contentSize(viewportSize, insets);
    final textScaler = MediaQuery.textScalerOf(context);
    final baseStyle = DefaultTextStyle.of(context).style;
    final boldText = MediaQuery.boldTextOf(context);
    final environment = TextLayoutEnvironment.of(context);
    final visibleReviewKeys =
        widget.reviewCounts?.entries
            .where((e) => e.value > 0)
            .map((e) => e.key)
            .toList() ??
        <int>[];
    visibleReviewKeys.sort();
    final reviewMeasureKey = (
      content,
      visibleReviewKeys.join(','),
      environment.geometryKey,
      boldText,
    );
    if (reviewMeasureKey != _reviewMeasureKey) {
      _reviewMeasureKey = reviewMeasureKey;
      _measuredReviews = ReviewColumnBadge.measureParagraphs(
        context,
        content,
        widget.reviewCounts,
      );
    }
    final reviews = _measuredReviews;
    final reviewKey = reviews.entries
        .map((e) => '${e.key}:${e.value.size}')
        .join(',');
    final countPaintKey = reviews.entries
        .map((e) => '${e.key}:${widget.reviewCounts?[e.key]}')
        .join(',');
    final paintKey =
        '$countPaintKey:${state.backgroundColor.toARGB32()}:${_resolveTextColor(state).toARGB32()}:${Theme.of(context).brightness}';
    if (paintKey != _reviewPaintKey) {
      _reviewPaintKey = paintKey;
      _paintRevision++;
      if (_nextPreviewLayout case final data?) {
        _nextChapterPreview = _buildPreviewPage(
          state,
          data.$1,
          data.$2,
          data.$3,
          data.$4,
        );
      }
      if (_prevPreviewLayout case final data?) {
        _prevChapterPreview = _buildPreviewPage(
          state,
          data.$1,
          data.$2,
          data.$3,
          data.$4,
        );
      }
    }
    final config = ParagraphConfig(
      fontSize: fontSize,
      lineHeight: lineHeight,
      paragraphSpacing: spacing,
      // [UI-fix v2.0.4 | 2026-08-08] 缩进档位（0-3 字符）接入排版引擎；
      // 字重接入测量（与渲染同参）— Qoder
      indent: indent > 0 ? fontSize * indent : 0,
      indentCount: indent,
      fontWeight: boldText ? FontWeight.bold : _fontWeightFor(textBold),
      fontStyle: _fontStyleFor(italic),
      justify: justify,
      textBottomJustify:
          widget.textBottomJustify && state.pageTurnMode != PageTurnMode.scroll,
      textColor: _resolveTextColor(state),
      backgroundColor: state.backgroundColor,
      letterSpacing: letterSpacing,
      fontFamily: fontFamily,
      // [UI-fix v2.0.5 | 2026-08-10] 中文分行开关接入排版引擎 — Reasonix
      useZhLayout: widget.useZhLayout,
      // [UI-fix v2.0.5 | 2026-08-10] 段首标点悬挂接入排版引擎 — Reasonix
      hangingPunctuation: widget.hangingPunctuation,
      // [UI_SYNC_REFACTOR S4 修 | 2026-09-06] 测量与渲染同参：渲染侧 Text
      // 继承 DefaultTextStyle 并应用系统文字缩放，测量侧同参注入 — Qoder
      baseStyle: baseStyle,
      textScaler: textScaler,
      textEnvironment: environment,
    );

    final doublePage = ReaderPaginationPolicy.doublePage(
      widget.doubleHorizontalPage,
      screenSize,
      state.pageTurnMode,
    );
    final signature = ReaderPaginationSignature(
      bookUrl: state.currentBook?.bookUrl,
      chapter: chapterIndex,
      content: content,
      chapterTitle: state.currentChapter?.title,
      isVolume: state.currentChapter?.isVolume ?? false,
      config: config,
      fontRevision: _fontRevision,
      boldText: boldText,
      textBold: textBold,
      margins: margins,
      insets: insets,
      chromeKey: widget.pageChrome.layoutKey,
      doublePage: doublePage,
      scroll: state.pageTurnMode == PageTurnMode.scroll,
      reviews: reviewKey,
    );
    final needRepaginate =
        (content.isNotEmpty ||
            (state.currentChapter?.title.isNotEmpty ?? false)) &&
        (signature != _paginationSignature ||
            screenSize != _paginatedScreenSize);

    if (!needRepaginate) {
      if (content.isEmpty) _layoutError = null;
      return;
    }

    final chrome = widget.pageChrome;
    final bounds = ReaderPaginationPolicy.bounds(
      content: screenSize,
      margins: margins,
      doublePage: doublePage,
      headerHeight: ReaderPageLayoutMetrics.headerBlockHeight(context, chrome),
      footerHeight: ReaderPageLayoutMetrics.footerBlockHeight(context, chrome),
    );
    final availableWidth = bounds.width;
    final availableHeight = bounds.height;
    if (availableWidth <= 0 || availableHeight <= 0) {
      _layoutGeneration++;
      _layoutSession?.cancel();
      _layoutSession = null;
      for (final session in _preloadSessions) {
        session.cancel();
      }
      // 记录失败视口，使恢复尺寸后重新命中原布局，旧任务不能覆盖错误状态。
      _paginatedScreenSize = screenSize;
      _layoutError = '阅读区域太小，请扩大窗口或减小页边距';
      return;
    }

    final title = ReaderTitleLayout(
      text: state.currentChapter?.title ?? '',
      chrome: chrome,
      isVolume: state.currentChapter?.isVolume ?? false,
    );

    // [UI_SYNC_REFACTOR S6 修 | 2026-09-08] 记录分页参数（相邻章预载复用
    // 同参）并在章变更时清相邻章预览（防旧章预览/位图残留）— Qoder
    // [换源预览修复 | 2026-09-26] 换源后同章号内容被整章替换（index 不变），
    // 仅按章号判变会让章边界承接页残留旧源文本——内容变化同样清相邻章
    // 预览与在途标记，eager 预载随后以新源 bookUrl 重建 — Qoder
    _pagedConfig = config;
    _pagedWidth = availableWidth;
    _pagedHeight = availableHeight;
    // 正文或任一排版参数变化时，相邻章预览和在途结果都必须失效。
    _layoutGeneration++;
    _layoutSession?.cancel();
    for (final session in _preloadSessions) {
      session.cancel();
    }
    _nextChapterPreview = null;
    _prevChapterPreview = null;
    _nextPreviewLayout = null;
    _prevPreviewLayout = null;
    _preloadingNext = false;
    _preloadingPrev = false;

    final notifier = ref.read(readerNotifierProvider.notifier);
    final sameChapter =
        chapterIndex == _paginatedChapterIndex &&
        state.currentBook?.bookUrl == _paginatedBookUrl;
    final sourceAnchor =
        notifier.currentSourceOffset ??
        (sameChapter &&
                state.currentChapterPos == _currentPageIndex &&
                _paginatedPages.isNotEmpty
            ? _paginatedPages[_currentPageIndex.clamp(
                    0,
                    _paginatedPages.length - 1,
                  )]
                  .sourceStart
            : null);
    final engine = ParagraphLayoutEngine(config: config, context: context);
    _pagedParagraphSpacingPx = engine.shaper.paragraphSpacingPx;
    // [UI-fix v2.0.4 | 2026-08-08] 首页容量单独下发（扣标题块）— Qoder
    final cacheKey = ReaderPaginationPolicy.chapterCacheKey(
      bookUrl: state.currentBook?.bookUrl,
      chapter: chapterIndex,
      content: content,
      config: config,
      width: availableWidth,
      height: availableHeight,
      titleKey: title.geometryKey,
      fontRevision: _fontRevision,
      reviews: reviewKey,
    );
    final cachedPages = _layoutCache.get(cacheKey);
    _layoutError = null;
    ChapterPaginationSession? session;
    if (cachedPages == null) {
      try {
        session = engine.startChapter(
          content,
          availableWidth,
          availableHeight,
          title: title,
          paragraphReviews: reviews,
        );
      } catch (error) {
        _layoutError = '$error';
      }
    }
    _layoutSession = session;
    _layoutComplete = session == null || session.complete;
    final pages = cachedPages ?? session?.pages ?? const <PageInfo>[];
    final target = ReaderPaginationTarget(
      requestedPage: state.currentChapterPos,
      sourceAnchor: sourceAnchor,
    );
    _waitingForAnchor = target.waiting(pages, complete: _layoutComplete);
    _paginatedPages = pages;
    _paginationSignature = signature;
    _paginatedContent = content;
    _paginatedChapterIndex = chapterIndex;
    _paginatedBookUrl = state.currentBook?.bookUrl;
    _paginatedChapterTitle = state.currentChapter?.title;
    _paginatedScreenSize = screenSize;
    _paginatedTextEnvironment = environment;
    _paginatedDoublePage = doublePage;
    _rebuildScrollLayout();
    // 开书已经清除历史页码；这里的页号只表示当前布局中的显式跳页操作。
    _currentPageIndex = target.resolve(pages);
    final resolvedAnchor =
        sourceAnchor ??
        (pages.isEmpty ? 0 : pages[_currentPageIndex].sourceStart);
    final generation = _layoutGeneration;
    final resolvedPage = _currentPageIndex;
    final initialComplete = _layoutComplete;
    final bookUrl = state.currentBook?.bookUrl;
    final task = ReaderPaginationTask(
      bookUrl: bookUrl,
      chapter: chapterIndex,
      generation: generation,
    );
    if (!_waitingForAnchor) {
      Future(() {
        if (!_isCurrentPaginationTask(task)) return;
        if (initialComplete) {
          _publishReadAloudPages();
          notifier.updateChapterPageCount(chapterIndex, pages.length);
        }
        notifier.updatePosition(resolvedPage, sourceOffset: resolvedAnchor);
        _restoreScrollAnchor(resolvedAnchor, generation);
      });
    }

    if (session != null && !session.complete) {
      unawaited(_continuePagination(session, engine, cacheKey, task, target));
    } else {
      _layoutCache.put(cacheKey, pages);
      _layoutMeasurements += engine.measurementCount;
    }

    // 章边界预载（页末预载下一章首屏 / 页首预载上一章末屏）
    if (_layoutComplete) _maybePreloadAdjacent(state, eager: true);
  }

  bool _isCurrentPaginationTask(ReaderPaginationTask task) {
    if (!mounted) return false;
    final live = ref.read(readerNotifierProvider);
    return task.matches(
      bookUrl: live.currentBook?.bookUrl,
      chapter: live.currentChapterIndex,
      generation: _layoutGeneration,
    );
  }

  Future<void> _continuePagination(
    ChapterPaginationSession session,
    ParagraphLayoutEngine engine,
    Object cacheKey,
    ReaderPaginationTask task,
    ReaderPaginationTarget target,
  ) async {
    while (!session.complete && !session.cancelled) {
      await SchedulerBinding.instance.endOfFrame;
      if (!_isCurrentPaginationTask(task)) {
        session.cancel();
        return;
      }
      try {
        // 上游延迟一页输出；首屏允许测量更多短段，仍受八毫秒测量预算限制。
        await session.advance(maxParagraphs: session.pages.isEmpty ? 16 : 8);
        if (!_isCurrentPaginationTask(task) || session.cancelled) {
          session.cancel();
          return;
        }
      } catch (error) {
        session.cancel();
        if (!_isCurrentPaginationTask(task)) return;
        setState(() => _layoutError = '正文排版失败：$error');
        return;
      }
      final pages = session.pages;
      if (!target.ready(pages, complete: session.complete)) continue;
      final wasWaiting = _waitingForAnchor;
      setState(() {
        _paginatedPages = pages;
        _rebuildScrollLayout();
        _layoutComplete = session.complete;
        _waitingForAnchor = false;
        if (wasWaiting) {
          _currentPageIndex = target.resolve(pages);
        }
      });
      final notifier = ref.read(readerNotifierProvider.notifier);
      if (wasWaiting) {
        notifier.updatePosition(
          _currentPageIndex,
          sourceOffset:
              target.sourceAnchor ?? pages[_currentPageIndex].sourceStart,
        );
        _restoreScrollAnchor(
          target.sourceAnchor ?? pages[_currentPageIndex].sourceStart,
          task.generation,
        );
      }
      if (session.complete) {
        _publishReadAloudPages();
        _layoutCache.put(cacheKey, pages);
        _layoutMeasurements += engine.measurementCount;
        notifier.updateChapterPageCount(task.chapter, pages.length);
        _maybePreloadAdjacent(ref.read(readerNotifierProvider), eager: true);
      }
    }
  }

  void _publishReadAloudPages() {
    final book = _paginatedBookUrl;
    if (book == null || !_layoutComplete || _paginatedPages.isEmpty) return;
    _audio.registerReadAloudPages(
      book,
      _paginatedChapterIndex,
      _paginatedContent,
      <ReadAloudPageRange>[
        for (final page in _paginatedPages)
          (start: page.sourceStart, end: page.sourceEnd),
      ],
    );
  }

  void _rebuildScrollLayout() {
    if (ref.read(readerNotifierProvider).pageTurnMode != PageTurnMode.scroll) {
      return;
    }
    final paragraphs = <ParagraphInfo>[];
    final positions = <(double, int, int)>[];
    var y = 0.0;
    var contentBottom = 0.0;
    ParagraphInfo? previous;
    for (var page = 0; page < _paginatedPages.length; page++) {
      for (final paragraph in _paginatedPages[page].paragraphs) {
        // 页内直接保留Rust最终间隔；拼页时补回未绘制的行后空白。
        final atPageStart = identical(
          paragraph,
          _paginatedPages[page].paragraphs.first,
        );
        final gap = page > 0 && atPageStart && previous != null
            ? previous.continuationSpacingAfter ?? 0
            : paragraph.spacingBefore ?? 0;
        y += gap;
        for (final line in paragraph.lines) {
          if (!paragraph.isTitle) positions.add((y, line.startIndex, page));
          y += line.height;
          contentBottom = math.max(contentBottom, y);
        }
        paragraphs.add(
          ParagraphInfo(
            lines: paragraph.lines,
            isTitle: paragraph.isTitle,
            continuationSpacingAfter: paragraph.continuationSpacingAfter,
            totalHeight: paragraph.totalHeight,
            startIndex: paragraph.startIndex,
            endIndex: paragraph.endIndex,
            chapterParagraphIndex: paragraph.chapterParagraphIndex,
            isParagraphEnd: paragraph.isParagraphEnd,
            spacingBefore: gap,
          ),
        );
        previous = paragraph;
      }
    }
    _scrollLinePositions = positions;
    _scrollLayout = PageInfo(
      paragraphs: paragraphs,
      totalHeight: contentBottom,
      sourceText: _paginatedContent,
      textEnvironment: _paginatedTextEnvironment,
    );
  }

  void _saveScrollAnchor() {
    if (_restoringScroll ||
        _waitingForAnchor ||
        _scrollLinePositions.isEmpty ||
        !_scrollController.hasClients) {
      return;
    }
    final body = _scrollBodyKey.currentContext?.findRenderObject();
    final viewport = context.findRenderObject();
    if (body is! RenderBox || viewport is! RenderBox) return;
    final inset = _contentInsets(context).top;
    final offset = math.max(
      0.0,
      viewport.localToGlobal(Offset(0, inset)).dy -
          body.localToGlobal(Offset.zero).dy,
    );
    var low = 0;
    var high = _scrollLinePositions.length - 1;
    while (low < high) {
      final middle = (low + high + 1) ~/ 2;
      if (_scrollLinePositions[middle].$1 <= offset) {
        low = middle;
      } else {
        high = middle - 1;
      }
    }
    final (_, source, page) = _scrollLinePositions[low];
    final notifier = ref.read(readerNotifierProvider.notifier);
    if (notifier.currentSourceOffset == source) return;
    _currentPageIndex = page;
    notifier.updatePosition(page, sourceOffset: source);
  }

  void _restoreScrollAnchor(int source, int generation) {
    if (ref.read(readerNotifierProvider).pageTurnMode != PageTurnMode.scroll) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          generation != _layoutGeneration ||
          !_scrollController.hasClients ||
          _scrollLinePositions.isEmpty) {
        return;
      }
      if (source <= 0) {
        _restoringScroll = true;
        _scrollController.jumpTo(0);
        _restoringScroll = false;
        return;
      }
      final body = _scrollBodyKey.currentContext?.findRenderObject();
      final viewport = context.findRenderObject();
      if (body is! RenderBox || viewport is! RenderBox) return;
      var index = 0;
      for (var i = 0; i < _scrollLinePositions.length; i++) {
        if (_scrollLinePositions[i].$2 > source) break;
        index = i;
      }
      final inset = _contentInsets(context).top;
      final bodyStart =
          body.localToGlobal(Offset.zero).dy -
          viewport.localToGlobal(Offset(0, inset)).dy +
          _scrollController.offset;
      final target = (bodyStart + _scrollLinePositions[index].$1).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _restoringScroll = true;
      _scrollController.jumpTo(target);
      _restoringScroll = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final corners = ReaderFooterGeometry.maybeOf(context)?.corners;
    if (corners != _footerCorners) {
      _footerCorners = corners;
      // 圆角只影响页脚绘制，刷新翻页快照而不改变分页缓存键。
      _paintRevision++;
    }
    ref.listen(
      readerSettingsProvider.select(
        (value) => (value.value?.fontFamily, value.value?.titleFontFamily),
      ),
      (previous, next) {
        if (previous != next) unawaited(_refreshFontFamily());
      },
    );
    ref.listen(readerFontsProvider, (previous, next) {
      if (previous?.value != next.value) unawaited(_refreshFontFamily());
    });
    final state = ref.watch(readerNotifierProvider);
    final notifier = ref.read(readerNotifierProvider.notifier);
    ref.listen(readerNotifierProvider, (previous, next) {
      if (previous != null &&
          previous.currentChapterIndex != next.currentChapterIndex &&
          _speechChapterTarget == null) {
        _manualChapterPending = true;
        _manualAloudNavigation();
      }
    });
    _scheduleAloudFollow();

    // [UI_SYNC_REFACTOR S4 修 | 2026-09-06] 章节切换加载中：保留上一章
    // 既有分页渲染（跳过重分页）——此前直接整树换成 LoadingIndicator，
    // cover 模式 AnimatedSwitcher 子树被卸载，加载完重新挂载时已无旧
    // child，过渡动画永不触发（章节切换翻页动画失效根因）。冻结期间
    // 键以 _paginatedChapterIndex 为章标识保持不变，加载完成重分页后
    // 键变化恰好触发一次"旧页 → 新页"过渡。首次打开（无既有分页）
    // 仍显示加载指示。
    if (state.isLoading && _paginatedPages.isEmpty) {
      return _chapterLoading(context);
    }
    if (state.isLoading && state.error == null) {
      // 冻结帧：不重分页、不响应排版参数变化（加载完成后统一重算）
      return _buildContent(context, state, repaginate: false);
    }

    // [F1-hunt F4 | 2026-09-24] 全屏 ErrorView 仅在「正文为空」时生效：
    // 章节加载失败（_loadChapterContent 失败路径已清空正文）→ 全屏错误
    // 页（重试/换源）；「刷新正文失败 / 换源重载失败」保留旧正文（不清
    // 空）并置 error → 此处不降级，仍渲染旧正文，失败由调用方 SnackBar
    // （「刷新正文失败：…」「更换书源后重载失败：…」）提示，避免刷新
    // 失败把整屏可读正文换成错误页（F4 缺陷②「刷新失败全屏降级」）
    if (state.error != null && state.chapterContent.isEmpty) {
      final book = state.currentBook;
      // [fix Task#24 | 2026-08-08] 正文/章节加载失败（如「正文为空」，多由换源
      // 匹配错书导致）时，除「重试」外引导用户「换源」逃离坏书源（对齐原版）— Qoder
      final isOnline =
          book != null &&
          book.origin != BookType.localTag &&
          !book.origin.startsWith(BookType.webDavTag);
      return ErrorView(
        message: state.error!,
        onRetry: () {
          if (book != null) {
            notifier.openBook(book);
          }
        },
        onSecondaryAction: isOnline
            ? () =>
                  GoRouter.of(context)
                      .pushAppRoute(AppRoutes.changeSource, extra: book)
            : null,
        secondaryActionLabel: '换源',
        secondaryActionIcon: Icons.swap_horiz,
      );
    }

    // [C4-hunt | 2026-09-24] 成功但正文为空（章节无正文 / 源返回空）：
    // 旧版渲染纯空白页且无任何提示（C4 缺陷）。现居中显示可见提示。
    // 不影响前置分支：加载中（LoadingIndicator）、冻结帧（isLoading &&
    // error == null）、F4 全屏 ErrorView（error != null && 正文为空）。
    if (state.error == null &&
        !state.isLoading &&
        state.currentBook != null &&
        state.chapters.isNotEmpty &&
        state.chapterContent.isEmpty &&
        (state.currentChapter?.title.isEmpty ?? true)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            '本章无正文',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: state.fontSize,
              color: _resolveTextColor(state),
            ),
          ),
        ),
      );
    }

    return _buildContent(context, state, repaginate: true);
  }

  Widget _chapterLoading(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return LoadingIndicator(
      message: AppStrings.loadingChapter,
      indicator: TickerMode(
        enabled: !MediaQuery.disableAnimationsOf(context),
        child: GlassProgressIndicator.circular(
          color: color,
          backgroundColor: color.withValues(alpha: 0.15),
          semanticLabel: AppStrings.loadingChapter,
        ),
      ),
    );
  }

  /// 组装正文内容（ [_paginateIfNeeded] 的触发时机集中在此）
  Widget _buildContent(
    BuildContext context,
    ReaderState state, {
    required bool repaginate,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) => _buildContentInBounds(
        context,
        state,
        constraints.biggest,
        repaginate: repaginate,
      ),
    );
  }

  Widget _buildContentInBounds(
    BuildContext context,
    ReaderState state,
    Size viewportSize, {
    required bool repaginate,
  }) {
    if (repaginate) {
      _paginateIfNeeded(context, state, viewportSize);
    }
    if (_manualChapterPending &&
        !state.isLoading &&
        _paginatedChapterIndex == state.currentChapterIndex &&
        _paginatedBookUrl == state.currentBook?.bookUrl &&
        !_waitingForAnchor) {
      _manualChapterPending = false;
      _manualAloudNavigation();
    }
    if (_layoutError case final message?) {
      return Center(child: Text(message, textAlign: TextAlign.center));
    }
    if (_waitingForAnchor) {
      return _chapterLoading(context);
    }

    final Widget content;
    // [UI_SYNC_REFACTOR S6 重构 | 2026-09-08] 翻页动画层整体替换为重构版
    // 系统（移植自 legado_flutter/features/reader/turn：快照缓存+拖拽控制器
    // +覆盖/滑动/仿真三画笔，数学对齐 Jingshiro/原版五委托）；滚动模式保留
    // 纵向滚动实现 — Qoder
    if (state.pageTurnMode == PageTurnMode.scroll) {
      content = _buildScrollContent(state);
    } else {
      content = _buildTurnContent(state);
    }

    // [UI-fix v2.0.4 | 2026-08-08] 鼠标滚轮翻页（对标原版 mouseWheelPage）：
    // 分页模式下用顶层覆盖 Listener 拦截滚轮事件（内层 PageView 的
    // Scrollable 在命中测试中先注册 pointerSignalResolver 会胜出，
    // 覆盖层居顶保证先注册；translucent 不影响下层点击/拖拽）；
    // 滚动模式不拦截，滚轮交给正文 Scrollable 自然滚动 — Qoder
    Widget result;
    if (state.pageTurnMode == PageTurnMode.scroll || !widget.mouseWheelPage) {
      result = content;
    } else {
      result = Stack(
        children: [
          content,
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerSignal: _handlePointerSignal,
              child: const SizedBox.expand(),
            ),
          ),
        ],
      );
    }

    // [fix Task#41 | 2026-08-09] pageTouchSlop 消费点（对标原版
    // ReadView.upPageSlopSquare：0=系统默认值，非 0 用自定义阈值）：
    // 经 MediaQuery.gestureSettings 覆写内层 PageView/Scrollable 拖拽
    // 识别器的 touchSlop；面板修改经共享阅读设置订阅触发
    // 重建即时生效（Scrollable.didChangeDependencies 重读 gestureSettings），
    // 无需重启阅读页
    // [fix Task#45 | 2026-08-09] 滚动模式不包裹（M3）：原版该阈值仅
    // 作用于横向翻页手势，滚动模式正文纵向起拖不应被放大阈值，
    // 强制取 0 走系统默认；其余模式保持现实现 — Qoder
    ref.watch(
      readerSettingsProvider.select(
        (value) => value.value?.interaction.pageTouchSlop,
      ),
    );
    final slop = state.pageTurnMode == PageTurnMode.scroll
        ? 0
        : ref
              .read(readerSettingsRepositoryProvider)
              .current
              .interaction
              .pageTouchSlop;
    if (widget.selectText && _paginatedPages.isNotEmpty) {
      final pages = state.pageTurnMode == PageTurnMode.scroll
          ? _paginatedPages
          : _paginatedPages.sublist(
              _currentPageIndex.clamp(0, _paginatedPages.length - 1),
              math.min(
                _currentPageIndex + (_isDoublePage ? 2 : 1),
                _paginatedPages.length,
              ),
            );
      result = ReaderSelectionRegion(
        controller: _selectionController,
        source: _paginatedContent,
        pages: pages,
        onTapUp: widget.onTapUp,
        child: result,
      );
    }
    return _applyPageTouchSlop(context, result, slop);
  }

  /// 按 pageTouchSlop 包裹自定义滑动阈值（0=系统默认值，不包裹）
  Widget _applyPageTouchSlop(BuildContext context, Widget child, int slop) {
    if (slop <= 0) return child;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        gestureSettings: DeviceGestureSettings(touchSlop: slop.toDouble()),
      ),
      child: child,
    );
  }

  /// 滚轮事件处理：下滚下一页 / 上滚上一页（300ms 节流）
  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (e) {
      final scroll = e as PointerScrollEvent;
      final now = DateTime.now();
      if (now.difference(_lastWheelTurn).inMilliseconds < 300) return;
      _lastWheelTurn = now;
      if (scroll.scrollDelta.dy > 0) {
        nextPageOrChapter();
      } else if (scroll.scrollDelta.dy < 0) {
        prevPageOrChapter();
      }
    });
  }

  /// textBold 档位 → FontWeight（0中/1粗/2细，对标原版
  /// TextFontWeightConverter 的 normal/bold/light）
  /// [C3 斜体 | Qoder UI] 斜体样式映射（测量/渲染同源调用）
  FontStyle? _fontStyleFor(bool italic) => italic ? FontStyle.italic : null;

  FontWeight? _fontWeightFor(int bold) {
    switch (bold) {
      case 1:
        return FontWeight.w700;
      case 2:
        return FontWeight.w300;
      default:
        return null;
    }
  }

  /// 正文使用样式仓储投影的最终文字色，与配色预览和配置注入一致。
  Color _resolveTextColor(ReaderState state) {
    return state.textColor;
  }

  /// 宿主提供稳定避让尺寸；独立使用时保留原有状态栏避让。
  EdgeInsets _contentInsets(BuildContext context) =>
      widget.contentInsets ??
      EdgeInsets.only(
        top: readerContentStatusBarInset(
          context,
          hideStatusBar: widget.pageChrome.hideStatusBar,
        ),
      );

  /// 放在页面快照内部，使背景、阴影与卷页覆盖完整视口。
  Widget _insetContent(Widget child) => LayoutBuilder(
    builder: (context, constraints) {
      final insets = _contentInsets(context);
      final geometry = ReaderFooterGeometry.maybeOf(context);
      final page = Padding(padding: insets, child: child);
      if (geometry == null) return page;
      return ReaderFooterGeometry(
        corners: geometry.corners,
        bounds: Rect.fromLTRB(
          insets.left,
          insets.top,
          constraints.maxWidth - insets.right,
          constraints.maxHeight - insets.bottom,
        ),
        child: page,
      );
    },
  );

  /// 章边界预载触发：末屏预载下一章首屏、首屏预载上一章末屏
  void _maybePreloadAdjacent(ReaderState state, {bool eager = false}) {
    final delta = ReaderPaginationPolicy.adjacentChapter(
      pageCount: _paginatedPages.length,
      currentPage: _currentPageIndex,
      doublePage: _isDoublePage,
      hasBook: state.currentBook != null,
      preloading: _preloadingNext || _preloadingPrev,
      hasPreviousChapter: state.hasPreviousChapter,
      hasNextChapter: state.hasNextChapter,
      previousReady: _prevChapterPreview != null,
      nextReady: _nextChapterPreview != null,
      eager: eager,
    );
    if (delta != null) unawaited(_preloadAdjacent(state, delta));
  }

  /// 预载相邻章边界页（下一章首屏 / 上一章末屏），供章边界动画与承接
  Future<void> _preloadAdjacent(ReaderState state, int delta) async {
    if (delta > 0) {
      if (_preloadingNext) return;
      _preloadingNext = true;
    } else {
      if (_preloadingPrev) return;
      _preloadingPrev = true;
    }
    final book = state.currentBook;
    final baseChapter = state.currentChapterIndex;
    // [换源预览修复 | 2026-09-26] 在途预载须同时校验 bookUrl：换源后章号
    // 往往不变，仅校验章号会让旧源拉取的结果回写、覆盖新源预览 — Qoder
    final baseBookUrl = book?.bookUrl;
    final generation = _layoutGeneration;
    final task = ReaderPaginationTask(
      bookUrl: baseBookUrl,
      chapter: baseChapter,
      generation: generation,
    );
    final target = baseChapter + delta;
    final config = _pagedConfig;
    final availableWidth = _pagedWidth;
    final availableHeight = _pagedHeight;
    var previewReady = false;
    try {
      if (book == null || config == null) return;
      if (target < 0 || target >= state.chapters.length) return;
      // 与当前章共用正文服务，在线未缓存时联网，本地保留路径还原。
      final content = await ref
          .read(chapterContentServiceProvider)
          .read(book.bookUrl, target);
      if (!mounted || !_isCurrentPaginationTask(task)) return;
      if (content.trim().isEmpty &&
          state.chapters[target].title.trim().isEmpty) {
        return;
      }
      final engine = ParagraphLayoutEngine(config: config, context: context);
      final titleLayout = ReaderTitleLayout(
        text: state.chapters[target].title,
        chrome: widget.pageChrome,
        isVolume: state.chapters[target].isVolume,
      );
      final cacheKey = ReaderPaginationPolicy.chapterCacheKey(
        bookUrl: state.currentBook?.bookUrl,
        chapter: target,
        content: content,
        config: config,
        width: availableWidth,
        height: availableHeight,
        titleKey: titleLayout.geometryKey,
        fontRevision: _fontRevision,
        reviews: '',
      );
      var pages = _layoutCache.get(cacheKey);
      if (pages == null) {
        final session = engine.startChapter(
          content,
          availableWidth,
          availableHeight,
          title: titleLayout,
        );
        _preloadSessions.add(session);
        try {
          while (!session.complete && !session.cancelled) {
            await SchedulerBinding.instance.endOfFrame;
            if (!_isCurrentPaginationTask(task)) {
              session.cancel();
              return;
            }
            await session.advance();
            if (!_isCurrentPaginationTask(task)) {
              session.cancel();
              return;
            }
          }
          if (session.cancelled) return;
          pages = session.pages;
          _layoutCache.put(cacheKey, pages);
          _layoutMeasurements += engine.measurementCount;
        } finally {
          session.cancel();
          _preloadSessions.remove(session);
        }
      }
      if (pages.isEmpty) {
        return;
      }
      final info = delta > 0 ? pages.first : pages.last;
      final pageIndex = delta > 0 ? 0 : pages.length - 1;
      final title = state.chapters[target].title;
      final paintState = ref.read(readerNotifierProvider);
      if (!_isCurrentPaginationTask(task)) return;
      final page = _buildPreviewPage(
        paintState,
        info,
        pageIndex,
        pages.length,
        title,
      );
      if (!mounted) return;
      setState(() {
        if (delta > 0) {
          _nextChapterPreview = page;
          _nextPreviewLayout = (info, pageIndex, pages!.length, title);
        } else {
          _prevChapterPreview = page;
          _prevPreviewLayout = (info, pageIndex, pages!.length, title);
        }
      });
      previewReady = true;
    } catch (_) {
      // 预载失败静默：章边界退化为瞬时填充
    } finally {
      if (generation == _layoutGeneration) {
        if (delta > 0) {
          _preloadingNext = false;
        } else {
          _preloadingPrev = false;
        }
        if (previewReady && mounted) {
          _maybePreloadAdjacent(ref.read(readerNotifierProvider), eager: true);
        }
      }
    }
  }

  /// 相邻章预览页构建（与 _buildTypographicPage 同参；selectText 关闭）
  Widget _buildPreviewPage(
    ReaderState state,
    PageInfo info,
    int pageIndex,
    int totalPages,
    String title,
  ) {
    final page = ReaderTypographicPage(
      pageInfo: info,
      pageIndex: pageIndex,
      totalPages: totalPages,
      pageChrome: widget.pageChrome,
      tipContext: _buildTipContext(
        state,
        pageIndex,
        totalPages,
        null,
        chapterTitle: title,
      ),
      fontSize: state.fontSize,
      lineHeight: state.lineHeight,
      paragraphSpacing: _pagedParagraphSpacingPx,
      backgroundColor: state.backgroundColor,
      textColor: _resolveTextColor(state),
      letterSpacing: widget.letterSpacing * state.fontSize,
      fontFamily: _fontFamily,
      justify: widget.textFullJustify,
      fontWeight: _fontWeightFor(widget.textBold),
      fontStyle: _fontStyleFor(widget.italic),
      selectText: false,
      footerColumns: _isDoublePage ? 2 : 1,
      contentPadding: EdgeInsets.only(
        left: widget.marginLeft,
        right: widget.marginRight,
        top: widget.marginTop,
        bottom: widget.marginBottom,
      ),
    );
    if (!_isDoublePage) return _insetContent(page);
    // 双页模式：预览按首屏双栏形态
    return _insetContent(
      Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: page),
          const Expanded(child: SizedBox.shrink()),
        ],
      ),
    );
  }

  /// 重构版翻页视图（滑动/仿真/覆盖/无动画统一入口）
  Widget _buildTurnContent(ReaderState state) {
    final notifier = ref.read(readerNotifierProvider.notifier);
    final screenIndex = _isDoublePage
        ? _currentPageIndex ~/ 2
        : _currentPageIndex;
    final screenCount = _isDoublePage
        ? (_paginatedPages.length + 1) ~/ 2
        : (_paginatedPages.isNotEmpty ? _paginatedPages.length : 1);
    return ReaderTurnView(
      key: _turnViewKey,
      selectionActive: _selectionController,
      layoutGeneration: _layoutGeneration,
      paintRevision: _paintRevision,
      mode: state.pageTurnMode,
      pageIndex: screenIndex,
      pageCount: screenCount,
      backPageColor: state.backgroundColor,
      buildPage: (i) => _insetContent(
        _isDoublePage
            ? _buildSpread(state, i)
            : _buildTypographicPage(state, i),
      ),
      onPageChanged: (i) {
        final page = _isDoublePage ? i * 2 : i;
        setState(() => _currentPageIndex = page);
        notifier.updatePosition(
          page,
          sourceOffset: _paginatedPages[page].sourceStart,
        );
        _manualAloudNavigation();
        // 翻页不触发重分页 → 此处驱动相邻章预载（原仅分页触发导致章末无预载）
        _maybePreloadAdjacent(ref.read(readerNotifierProvider));
      },
      chapterPrevPage: _prevChapterPreview,
      chapterNextPage: _nextChapterPreview,
      onTurnChapterPrev: notifier.prevChapter,
      onTurnChapterNext: notifier.nextChapter,
      hasChapterPrev: state.hasPreviousChapter,
      hasChapterNext: _layoutComplete && state.hasNextChapter,
    );
  }

  Widget _buildScrollContent(ReaderState state) {
    // [UI-fix v2.0.4 | 2026-08-08] 文字色经自定义配色解析 — Qoder
    final textColor = _resolveTextColor(state);

    return _insetContent(
      NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.depth != 0) return false;
          if (notification is ScrollStartNotification &&
              notification.dragDetails != null) {
            _manualScrollActive = true;
            _manualNavigationGeneration++;
            _detachForManualScroll();
          } else if (notification is ScrollEndNotification &&
              _manualScrollActive) {
            _manualScrollActive = false;
            _manualAloudNavigation();
          }
          return false;
        },
        child: SingleChildScrollView(
          controller: _scrollController,
          // [UI-fix v2.0.3 | 2026-08-06] 滚动模式边距接页面边距配置 — Qoder
          padding: EdgeInsets.only(
            left: widget.marginLeft,
            right: widget.marginRight,
            top: widget.marginTop,
            bottom: widget.marginBottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 滚动模式：渲染所有分页内容（使用排版引擎的分行结果）
              if (_paginatedPages.isNotEmpty && _scrollLayout != null)
                ReaderTextContent(
                  key: _scrollBodyKey,
                  pageInfo: _scrollLayout!,
                  fontSize: state.fontSize,
                  lineHeight: state.lineHeight,
                  paragraphSpacing: _pagedParagraphSpacingPx,
                  textColor: textColor,
                  readAloudRange: _aloudRange,
                  readAloudColor: Theme.of(context).colorScheme.primary,
                  // [UI-fix v2.0.2 | 2026-08-06] 字距/字体/两端对齐透传到正文渲染 — Qoder
                  // [UI-fix v2.0.4 | 2026-08-08] 字距 em→px；字重接线 — Qoder
                  letterSpacing: widget.letterSpacing * state.fontSize,
                  fontFamily: _fontFamily,
                  fontWeight: _fontWeightFor(widget.textBold),
                  fontStyle: _fontStyleFor(widget.italic),
                  justify: widget.textFullJustify,
                  // [UI-fix v2.0.3 | 2026-08-08] selectText 开关接入长按选择 — Qoder
                  selectText: widget.selectText,
                  reviewCounts: widget.reviewCounts,
                  onReviewTap: widget.onReviewTap,
                )
              else if (!state.isLoading)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(48),
                    child: Text(
                      AppStrings.noContent,
                      style: TextStyle(
                        fontSize: state.fontSize,
                        color: textColor.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  /// 渲染排版引擎分页后的单页内容
  ///
  /// [UI-fix v2.0.5 | 2026-08-10] 双页模式：`doublePageSide` 为 'left'/'right'
  /// 时按栏调整左右边距（中间间隙 8px，与分页可用宽严格一致）— Reasonix
  Widget _buildTypographicPage(
    ReaderState state,
    int pageIndex, {
    String? doublePageSide,
  }) {
    final safeIndex = _paginatedPages.isEmpty
        ? 0
        : pageIndex.clamp(0, _paginatedPages.length - 1);
    final pageInfo = _paginatedPages.isEmpty
        ? null
        : _paginatedPages[safeIndex];

    // 计算全局页索引（章起始全局索引 + 章内页索引）
    final notifier = ref.read(readerNotifierProvider.notifier);
    final chapterStart = notifier.paginator.globalIndexForChapterStart(
      state.currentChapterIndex,
    );
    final globalIndex = chapterStart >= 0 ? chapterStart + safeIndex : null;

    return ReaderTypographicPage(
      pageInfo: pageInfo,
      pageIndex: safeIndex,
      totalPages: _paginatedPages.length,
      footerColumn: doublePageSide == 'right' ? 1 : 0,
      footerColumns: doublePageSide == null ? 1 : 2,
      pageChrome: widget.pageChrome,
      tipContext: _buildTipContext(
        state,
        safeIndex,
        _paginatedPages.length,
        globalIndex,
      ),
      fontSize: state.fontSize,
      lineHeight: state.lineHeight,
      paragraphSpacing: _pagedParagraphSpacingPx,
      backgroundColor: state.backgroundColor,
      // [UI-fix v2.0.4 | 2026-08-08] 文字色经自定义配色解析；字距/字体/
      // 对齐/字重透传到分页页渲染（与测量同参）— Qoder
      textColor: _resolveTextColor(state),
      readAloudRange: _aloudRange,
      readAloudColor: Theme.of(context).colorScheme.primary,
      letterSpacing: widget.letterSpacing * state.fontSize,
      fontFamily: _fontFamily,
      justify: widget.textFullJustify,
      fontWeight: _fontWeightFor(widget.textBold),
      fontStyle: _fontStyleFor(widget.italic),
      // [UI-fix v2.0.3 | 2026-08-08] selectText 开关接入分页页正文渲染 — Qoder
      selectText: widget.selectText,
      // [UI-fix v2.0.3 | 2026-08-06] 分页页内容边距接配置 — Qoder
      contentPadding: doublePageSide == null
          ? EdgeInsets.only(
              left: widget.marginLeft,
              right: widget.marginRight,
              top: widget.marginTop,
              bottom: widget.marginBottom,
            )
          : EdgeInsets.only(
              left: doublePageSide == 'left' ? widget.marginLeft : 8,
              right: doublePageSide == 'right' ? widget.marginRight : 8,
              top: widget.marginTop,
              bottom: widget.marginBottom,
            ),
      globalPageIndex: globalIndex,
      globalTotalPages: state.totalPages > 0 ? state.totalPages : null,
      reviewCounts: widget.reviewCounts,
      onReviewTap: widget.onReviewTap,
    );
  }

  ReaderTipContext _buildTipContext(
    ReaderState state,
    int pageIndex,
    int totalPages,
    int? globalIndex, {
    String? chapterTitle,
  }) {
    return ReaderTipContext(
      bookName: state.currentBook?.name ?? '',
      // [UI_SYNC_REFACTOR S4 修] 章题取分页同源快照（加载冻结帧不串章）— Qoder
      chapterTitle:
          chapterTitle ??
          _paginatedChapterTitle ??
          state.currentChapter?.title ??
          '',
      pageIndex: pageIndex,
      totalPages: totalPages,
      globalPageIndex: globalIndex,
      globalTotalPages: state.totalPages > 0 ? state.totalPages : null,
      readProgress: state.readingProgress,
      chapterIndex: state.currentChapterIndex,
      chapterCount: state.chapters.length,
      battery: _battery,
    );
  }

  /// [UI-fix v2.0.5 | 2026-08-10] 双页模式：一屏左右双栏
  ///（左 = 2s、右 = 2s+1；奇数页数时末屏右栏留白占位）— Reasonix
  Widget _buildSpread(ReaderState state, int screenIndex) {
    final left = screenIndex * 2;
    final right = left + 1;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _buildTypographicPage(state, left, doublePageSide: 'left'),
        ),
        Expanded(
          child: right < _paginatedPages.length
              ? _buildTypographicPage(state, right, doublePageSide: 'right')
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
