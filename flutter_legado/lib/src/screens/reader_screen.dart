import 'package:flutter_legado/src/domain/services/book_metadata_policy.dart';

import '../providers/chapter_content_provider.dart';
import '../features/book_sources/book_source_repository_provider.dart';
import '../providers/change_source/source_switch_dependencies.dart';
import '../providers/book_content_provider.dart';
import '../providers/reader/reader_settings_provider.dart';
import '../domain/models/reader_interaction_settings.dart';
import '../widgets/reader/reader_tap_hit_test.dart';
import '../app/session/reader_theme_session.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../l10n/app_localization.dart';
import '../models/book.dart';
import '../models/book_source.dart';
import '../models/source_match.dart';
import '../providers/audio/audio_notifier.dart';
import '../features/bookmarks/bookmarks.dart';
import '../features/bookshelf/bookshelf.dart';
import '../providers/general_settings_provider.dart';
import '../providers/reader/reader_notifier.dart';
import '../providers/theme/system_bar_controller.dart';
import '../routes.dart';
import '../services/system_brightness.dart';
import '../services/system_bar_service.dart';
import '../utils/app_route_observer.dart';
import '../widgets/reader/read_aloud_bar.dart';
import '../providers/audio/read_aloud_capsule.dart';
import '../widgets/reader/auto_turn_panel.dart';
import '../widgets/reader/reader_page_chrome.dart';
import '../widgets/reader/reader_image_dominant_body.dart';
import '../widgets/reader/reader_page_view.dart';
import '../widgets/reader/reader_settings_sheet.dart';
import '../widgets/reader/reader_status_strip.dart';
import '../widgets/reader/reader_menu_panel.dart';
import '../widgets/reader/reader_menu_theme.dart';
import '../widgets/reader/review_detail_sheet.dart';
import '../utils/comic_image_utils.dart';
import '../utils/source_login_prompt.dart';

/// 阅读器页面（Riverpod ConsumerStatefulWidget 薄壳）
///
/// 状态由 [ReaderNotifier] 管理；分页/翻页渲染由 [ReaderPageView] 承担；
/// 工具栏/目录/设置/状态栏拆分为独立子组件（widgets/reader/）。
/// 本文件仅负责编排：高级配置、自动翻页、点击区域、预加载、书签、正文搜索。
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key});

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen>
    with WidgetsBindingObserver, RouteAware {
  final _systemBarOwner = Object();
  late SystemBarController _systemBars;
  PageRoute<dynamic>? _systemBarRoute;
  bool _readerRouteActive = true;
  final GlobalKey<ReaderPageViewState> _pageViewKey =
      GlobalKey<ReaderPageViewState>();

  Size? _insetViewportSize;
  EdgeInsets _bodySystemInsets = EdgeInsets.zero;
  double? _cutoutPixelRatio;
  double _cutoutBottomInset = 0;
  int _cutoutGeneration = 0;

  /// 系统栏开关不改变正文分页；方向或窗口尺寸变化后重新采样。
  EdgeInsets _stableBodyInsets(BuildContext context) {
    final media = MediaQuery.of(context);
    if (_insetViewportSize != media.size ||
        _cutoutPixelRatio != media.devicePixelRatio) {
      _insetViewportSize = media.size;
      _cutoutPixelRatio = media.devicePixelRatio;
      _bodySystemInsets = media.viewPadding;
      _cutoutBottomInset = 0;
      unawaited(
        _loadCutoutBottomInset(++_cutoutGeneration, media.devicePixelRatio),
      );
    } else {
      final current = media.viewPadding;
      _bodySystemInsets = EdgeInsets.fromLTRB(
        math.max(_bodySystemInsets.left, current.left),
        math.max(_bodySystemInsets.top, current.top),
        math.max(_bodySystemInsets.right, current.right),
        math.max(_bodySystemInsets.bottom, current.bottom),
      );
    }
    return _bodySystemInsets;
  }

  Future<void> _loadCutoutBottomInset(int generation, double pixelRatio) async {
    final physical = await SystemBarService.displayCutoutBottomInset();
    if (!mounted || generation != _cutoutGeneration) return;
    final logical = physical / pixelRatio;
    if (logical != _cutoutBottomInset) {
      setState(() => _cutoutBottomInset = logical);
    }
  }

  /// 自动翻页定时器
  Timer? _autoTimer;

  /// 上一章是否处于加载状态（用于检测章节加载完成以触发预加载）
  bool _wasLoading = false;

  /// 已触发过预加载的章节索引（避免重复预加载）
  int _lastPreloadedIndex = -1;

  /// 段评摘要（P2-9 ruleReview；禁止接本地 CommentService）
  Map<int, int> _reviewCounts = {};
  Map<int, String> _reviewKeys = {};
  String? _reviewSourceJson;
  int _reviewLoadToken = 0;

  // [UI-fix v2.0.3 | 2026-08-08] 自动换源（autoChangeSource）防循环状态 — Qoder

  /// 自动换源进行中（避免并发触发）
  bool _autoSwitching = false;

  /// 当前正在自动换源的书 bookUrl（换书时重置尝试计数）
  String? _autoSwitchBookUrl;

  /// 同一本书连续自动换源尝试次数（上限 3 次，避免无可用源时死循环）
  int _autoSwitchAttempts = 0;

  static const int _autoSwitchMaxAttempts = 3;

  bool _settingsLoaded = false;

  /// [P2-30] 退出判定进行中标记（防系统返回连点触发多路判定/重复弹窗）
  bool _exitPending = false;
  late final ReaderThemeSession _themeSession;

  @override
  void initState() {
    super.initState();
    _themeSession = ref.read(readerThemeSessionProvider)..reset();
    _systemBars = ref.read(systemBarControllerProvider);
    // F6：音量键翻页（对标 volumeKeyPage / volumeKeyPageOnPlay）
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
    // [C3-hunt | 2026-09-24] 注册 App 生命周期观察者：切后台/分离时
    // 落盘章内进度（见 didChangeAppLifecycleState）
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic> && route != _systemBarRoute) {
      systemBarRouteObserver.unsubscribe(this);
      _systemBarRoute = route;
      systemBarRouteObserver.subscribe(this, route);
    }
    if (!_settingsLoaded) {
      _settingsLoaded = true;
      unawaited(_loadReaderSettings());
    }
  }

  @override
  void didChangePlatformBrightness() {
    // 跟随系统时同步正文默认配色，显式主题与自定义背景由解析器保留。
    unawaited(
      ref
          .read(readerNotifierProvider.notifier)
          .reapplyBackgroundForCurrentTheme(),
    );
  }

  @override
  void dispose() {
    // 退出阅读才清除覆盖；目录、设置和后台切换仍属于同一会话。
    _themeSession.reset();
    _cutoutGeneration++;
    systemBarRouteObserver.unsubscribe(this);
    _systemBars.releaseReader(_systemBarOwner);
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    // [C3-hunt | 2026-09-24] 注销生命周期观察者（与 initState 配对）
    WidgetsBinding.instance.removeObserver(this);
    _autoTimer?.cancel();
    // 系统栏由共享控制器恢复最新应用设置；方向保持原退出语义。
    SystemChrome.setPreferredOrientations(const []);
    unawaited(
      SystemBrightness.setFollowSystem(true).catchError((Object error) {
        debugPrint('退出阅读时恢复系统亮度失败: $error');
      }),
    );
    super.dispose();
  }

  @override
  void didPush() {
    _readerRouteActive = true;
    _applySystemChrome();
  }

  @override
  void didPopNext() {
    _readerRouteActive = true;
    _applySystemChrome();
  }

  @override
  void didPushNext() {
    _readerRouteActive = false;
    _systemBars.releaseReader(_systemBarOwner);
  }

  @override
  void didPop() {
    _readerRouteActive = false;
    _systemBars.releaseReader(_systemBarOwner);
  }

  // [C3-hunt | 2026-09-24] App 生命周期 → 章内进度落盘
  //
  // 对齐原版 ReadBookActivity.onPause() → ReadBook.saveRead()
  // （切后台即落盘，进程被回收/划掉不丢章内位置）。修复前章内进度
  // （updatePosition）只改内存 state，落库仅在翻章/目录跳章/换源重载/
  // PopScope 返回退出时触发——按 HOME 进后台后 force-stop 重进会回到
  // 上次翻章位置（章首）（C3 缺陷，真机实测：翻到 4/16 页 → HOME →
  // force-stop → 重进回到 1/16，DB durChapterPos 仍 0）。
  //
  // 与既有 PopScope 路径的关系：触发条件不同（系统生命周期 vs 返回退出），
  // 落库操作收敛到同一个幂等的 notifier.saveProgress()（写库失败静默，
  // 重复写同一进度无副作用），两者可共存互不冲突。
  //
  // 不引入「章内翻页节流落库」：原版仅在 换章/后台/退出 时机落盘，
  // 逐页写库属超范围行为变更；C3 缺陷（后台/被杀丢位置）由本钩子完整修复。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        // 切后台/窗口分离/进程分离：当前章内位置立即落库
        unawaited(ref.read(readerNotifierProvider.notifier).saveProgress());
      case AppLifecycleState.resumed:
      case AppLifecycleState.hidden:
        break;
    }
  }

  // ===== [UI-fix v2.0.3 | 2026-08-08] MoreConfig 第①批系统级生效 =====

  /// 应用隐藏状态栏/导航栏与屏幕方向（对标原版 MoreConfigDialog
  /// onSharedPreferenceChanged：hideStatusBar/hideNavigationBar → UP_CONFIG
  /// 重建沉浸式；screenOrientation → setOrientation）— Qoder
  ///
  /// [menuVisible] 为 true 时强制显示状态栏（对标原版
  /// `upSystemUiVisibility(toolBarHide=false)`，ReadMenu 展开时不隐藏状态栏）。
  void _applySystemChrome({bool? menuVisible}) {
    final cfg = ref.read(readerSettingsRepositoryProvider).current.screen;
    if (!_readerRouteActive) return;
    final showMenu =
        menuVisible ?? ref.read(readerNotifierProvider).showControls;
    _systemBars.updateReader(_systemBarOwner, (
      statusBarVisible: !cfg.hideStatusBar || showMenu,
      navigationBarVisible: !cfg.hideNavigationBar || showMenu,
    ));
    SystemChrome.setPreferredOrientations(_orientationsFor(cfg.orientation));
  }

  /// 原版 screen_direction_value → Flutter DeviceOrientation 映射
  List<DeviceOrientation> _orientationsFor(int orientation) {
    switch (orientation) {
      case 1: // 竖屏
        return const [DeviceOrientation.portraitUp];
      case 2: // 横屏
        return const [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ];
      case 3: // 自动(传感器)
        return DeviceOrientation.values.toList();
      case 4: // 反向竖屏
        return const [DeviceOrientation.portraitDown];
      case 5: // 反向横屏
        return const [DeviceOrientation.landscapeRight];
      default: // 跟随系统：空列表解除锁定
        return const [];
    }
  }

  Future<void> _loadReaderSettings() async {
    try {
      await ref.read(readerSettingsRepositoryProvider).load();
      if (mounted) _applySystemChrome();
    } catch (error) {
      debugPrint('阅读设置读取失败：$error');
    }
  }

  /// F6：音量键翻页（仅 Android 有效；桌面无音量键事件）
  bool _onHardwareKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final isVolUp = event.logicalKey == LogicalKeyboardKey.audioVolumeUp;
    final isVolDown = event.logicalKey == LogicalKeyboardKey.audioVolumeDown;
    if (!isVolUp && !isVolDown) return false;

    final cfg = ref.read(readerSettingsRepositoryProvider).current.interaction;
    final aloud = ref.read(audioNotifierProvider).isPlaying;
    final allow = cfg.volumeKeyPage && (!aloud || cfg.volumeKeyPageOnPlay);
    if (!allow) return false;

    final pageView = _pageViewKey.currentState;
    if (pageView == null) return false;
    if (isVolDown) {
      pageView.nextPageOrChapter();
    } else {
      pageView.prevPageOrChapter();
    }
    return true; // 消费事件，避免系统调音量
  }

  /// 根据配置同步自动翻页定时器
  void _syncAutoTimer() {
    _autoTimer?.cancel();
    _autoTimer = null;
    final cfg = ref.read(readerSettingsRepositoryProvider).current.autoPageTurn;
    if (!cfg.enabled) return;
    final seconds = cfg.intervalSeconds.round().clamp(3, 120);
    _autoTimer = Timer.periodic(Duration(seconds: seconds), (_) {
      if (!mounted) return;
      final pageView = _pageViewKey.currentState;
      if (pageView == null) return;
      if (cfg.forward) {
        pageView.nextPageOrChapter();
      } else {
        pageView.prevPageOrChapter();
      }
    });
  }

  /// 加载当前章段评摘要（对齐 ReadBookActivity.loadReviewSummaryIfNeeded）
  Future<void> _loadReviewSummary() async {
    final token = ++_reviewLoadToken;
    final state = ref.read(readerNotifierProvider);
    final book = state.currentBook;
    if (book == null || book.origin.isEmpty) {
      if (mounted && token == _reviewLoadToken) {
        setState(() {
          _reviewCounts = {};
          _reviewKeys = {};
          _reviewSourceJson = null;
        });
      }
      return;
    }
    try {
      final sources = await ref
          .read(bookSourceRepositoryProvider)
          .getBookSources();
      BookSource? matched;
      for (final s in sources) {
        if (s.bookSourceUrl == book.origin) {
          matched = s;
          break;
        }
      }
      if (matched == null) {
        if (mounted && token == _reviewLoadToken) {
          setState(() {
            _reviewCounts = {};
            _reviewKeys = {};
            _reviewSourceJson = null;
          });
        }
        return;
      }
      final rr = matched.ruleReview;
      final isJs = (matched.mainJs ?? '').trim().isNotEmpty;
      final enabled =
          isJs ||
          (rr != null &&
              rr.enabled &&
              (rr.reviewSummaryUrl ?? '').trim().isNotEmpty);
      if (!enabled) {
        if (mounted && token == _reviewLoadToken) {
          setState(() {
            _reviewCounts = {};
            _reviewKeys = {};
            _reviewSourceJson = null;
          });
        }
        return;
      }
      final chapter = state.currentChapter;
      final request = <String, dynamic>{
        'chapterUrl': chapter?.url ?? '',
        'book': book.toJson(),
        if (chapter != null) 'chapter': chapter.toJson(),
      };
      final sourceJson = jsonEncode(matched.toJson());
      final summary = await ref
          .read(reviewServiceProvider)
          .reviewGetSummary(sourceJson, request);
      if (!mounted || token != _reviewLoadToken) return;
      setState(() {
        _reviewCounts = summary.counts;
        _reviewKeys = summary.keys;
        _reviewSourceJson = sourceJson;
      });
    } catch (_) {
      if (mounted && token == _reviewLoadToken) {
        setState(() {
          _reviewCounts = {};
          _reviewKeys = {};
          _reviewSourceJson = null;
        });
      }
    }
  }

  void _onReviewTap(int paragraphIndex, int count) {
    final state = ref.read(readerNotifierProvider);
    final book = state.currentBook;
    final chapter = state.currentChapter;
    final sourceJson = _reviewSourceJson;
    if (book == null || chapter == null || sourceJson == null) return;
    final paraData = _reviewKeys[paragraphIndex] ?? '$paragraphIndex';
    ReviewDetailSheet.show(
      context,
      service: ref.read(reviewServiceProvider),
      sourceJson: sourceJson,
      bookUrl: book.bookUrl,
      chapterUrl: chapter.url,
      chapterIndex: state.currentChapterIndex,
      paragraphIndex: paragraphIndex,
      paragraphData: paraData,
      totalCount: count,
      bookJson: book.toJson(),
      chapterJson: chapter.toJson(),
    );
  }

  /// 章节内容加载完成后，后台预加载相邻章节
  void _maybePreloadAdjacentChapters(ReaderState state) {
    if (_wasLoading && !state.isLoading && state.error == null) {
      final index = state.currentChapterIndex;
      if (index != _lastPreloadedIndex) {
        _lastPreloadedIndex = index;
        _preloadAdjacentChapters(state);
        unawaited(_loadReviewSummary());
      }
    }
    _wasLoading = state.isLoading;
  }

  /// 预加载当前章节的前后各 2 章内容，提升翻页阅读体验（静默失败）
  ///
  /// 对齐计划 Phase 2.7：前后各 2 章的 API 调用编排，实现翻页无等待感。
  /// 此处仅决定「何时预载」，文本解析/净化/替换由 Rust 内部完成。
  /// 获取策略统一交给正文服务，本地书保留相对文件路径还原。
  ///
  /// [F1-hunt F5 | 2026-09-24] getChapterContent → getChapterContentFull
  /// （缓存+网络合并，与阅读器章节加载 / ReaderPageView 相邻章预载同
  /// 链路）：修复前 getChapterContent 仅读本地缓存（Rust 侧未缓存时
  /// 返回 need_fetch 占位，结果被丢弃），在线书从未缓存的章节上预载
  /// 是 no-op，±2 章暖缓存窗口完全失效。保留预载（±2 窗口意图不变），
  /// 改走 Full 路径：缓存命中直接返回、未命中联网抓取并回写缓存，
  /// 无需 Rust 侧改动。
  void _preloadAdjacentChapters(ReaderState state) {
    final book = state.currentBook;
    final chapters = state.chapters;
    if (book == null || chapters.isEmpty) return;

    final index = state.currentChapterIndex;

    // 前后各预加载 2 章（按距离由近及远，越靠近当前章越优先）
    for (var offset = 1; offset <= 2; offset++) {
      final next = index + offset;
      if (next < chapters.length) {
        unawaited(
          ref
              .read(chapterContentServiceProvider)
              .read(book.bookUrl, next)
              .catchError((_) => ''),
        );
      }
      final prev = index - offset;
      if (prev >= 0) {
        unawaited(
          ref
              .read(chapterContentServiceProvider)
              .read(book.bookUrl, prev)
              .catchError((_) => ''),
        );
      }
    }
  }

  // ===== [P2-30 | 未入架书退出提示] =====
  //
  // 对齐原版 ReadBookActivity.finish() 三路语义（参考版 closeReadBook 同款）：
  // 1. 已入架（DB 记录存在且未打 notShelf 位）→ 直接退出（现状不变）；
  // 2. 未入架 + 「返回时提示放入书架」开关（PrefKeys.showAddToShelfAlert，
  //    既有设置项，默认开）关闭 → 静默退出且清理未入架书的临时落库记录
  //    （对齐原版 !showAddToShelfAlert 分支 removeFromBookshelf，书不残留）；
  // 3. 未入架 + 开关开启 → 弹「放入书架」对话框：
  //    确认 → 清 notShelf 位入架（复用 bookshelf addBook upsert）→ 落库进度 → 退出；
  //    取消/ dismiss → 清理未入架临时记录并退出（书不残留）。
  //
  // 在架判定以 DB 记录的 notShelf 位为准（BookMetadataPolicy.isInBookshelf）：
  // 路由带入的内存 Book 是瘦壳（openBook 只回写媒体类型位，不带 notShelf 位），
  // 不可作为在架依据——与 book_info_screen 的判定数据源一致。

  /// 退出判定入口（PopScope 拦截所有 pop 尝试后调用）
  Future<void> _onExitPop(BuildContext context) async {
    if (_exitPending) return;
    _exitPending = true;
    try {
      final book = ref.read(readerNotifierProvider).currentBook;
      if (book == null) {
        if (context.mounted) Navigator.pop(context);
        return;
      }
      // 在架判定：DB 记录权威（查询失败按未入架处理，对齐原版默认
      // inBookshelf=false 语义；未入架书不会走到删除在架书的分支）
      var inShelf = false;
      try {
        final dbBook = await ref
            .read(bookshelfRepositoryProvider)
            .getBook(book.bookUrl);
        inShelf = BookMetadataPolicy.isInBookshelf(dbBook);
      } catch (_) {
        inShelf = false;
      }
      final notifier = ref.read(readerNotifierProvider.notifier);
      if (inShelf) {
        // 已入架 → 直接退出（现状不变：进度落库 + pop）
        await notifier.saveProgress();
        if (context.mounted) Navigator.pop(context);
        return;
      }
      // 未入架：读「返回时提示放入书架」开关（既有设置项，默认开启）
      final bool showAlert;
      try {
        showAlert = (await ref.read(generalSettingsRepositoryProvider).load())
            .showAddToShelfAlert;
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('读取返回入架设置失败，请重试')));
        }
        return;
      }
      if (!context.mounted) return;
      if (!showAlert) {
        // 开关关 → 静默退出且书不残留（对齐原版第二路）
        await _removeNotShelfBook(book);
        if (context.mounted) Navigator.pop(context);
        return;
      }
      // 默认路 → 弹「放入书架」提示
      final confirmed = await _showAddToShelfDialog(context, book.name);
      if (!context.mounted) return;
      if (confirmed) {
        // 确认 → 入架（复用 book_info_screen 同款调用：清 notShelf 位 +
        // addBook 原地 upsert，不会级联删章节目录）→ 落库进度 → 退出
        final ok = await ref
            .read(bookshelfNotifierProvider.notifier)
            .addBook(
              book.copyWith(bookType: book.bookType & ~BookType.notShelf),
            );
        if (!context.mounted) return;
        if (!ok) {
          // 入架失败：可见提示且不退出（项目规则：用户可见失败必须提示）
          final err = ref.read(bookshelfNotifierProvider).error;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err != null ? '加入书架失败：$err' : '加入书架失败')),
          );
          return;
        }
        await notifier.saveProgress();
        if (context.mounted) Navigator.pop(context);
      } else {
        // 取消 → 退出且未入架书不残留（对齐原版第三路 noButton 分支）
        await _removeNotShelfBook(book);
        if (context.mounted) Navigator.pop(context);
      }
    } finally {
      _exitPending = false;
    }
  }

  /// 清理未入架书的临时落库记录（对齐原版 removeFromBookshelf：
  /// 仅删除本次会话以 notShelf 临时入库的书；已入架书不会进入本方法）
  Future<void> _removeNotShelfBook(Book book) async {
    try {
      await ref.read(bookshelfRepositoryProvider).deleteBook(book.bookUrl);
    } catch (_) {
      // 清理失败不阻断退出（极端残留仅影响占位行，不污染书架列表）
    }
  }

  /// 「放入书架」确认对话框（对齐参考版 AppAlertDialog：标题「放入书架」、
  /// 正文「是否将《书名》放入书架？」、取消/确认；圆角按钮走主题
  /// dialogTheme 28dp 大圆角容器 + FilledButton 确认，与既有 Dialog 风格一致）。
  /// 返回 true=确认入架；false=取消/dismiss（含系统返回关闭对话框，
  /// 对齐参考版 onDismiss → ExitWithoutAddingCurrentBookToBookshelf）。
  Future<bool> _showAddToShelfDialog(BuildContext context, String bookName) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('放入书架'),
        content: Text('是否将《$bookName》放入书架？'),
        actionsAlignment: MainAxisAlignment.end,
        actionsPadding: const EdgeInsets.fromLTRB(12, 0, 16, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认'),
          ),
        ],
      ),
    ).then((v) => v ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(readerNotifierProvider);
    final notifier = ref.read(readerNotifierProvider.notifier);
    // 朗读控制条显隐依赖全局朗读状态（朗读进行中时替代底部功能栏）
    final audio = ref.watch(audioNotifierProvider);
    final capsule = ref.watch(readAloudCapsuleProvider);
    final book = state.currentBook;
    final aloudActive =
        book != null &&
        audio.bookUrl == book.bookUrl &&
        audio.state != PlayerState.idle;

    _maybePreloadAdjacentChapters(state);

    // 必应漫画等：正文仅为 <img> HTML 时勿走文本排版（会刷裸标签）
    final imageDominant =
        book != null &&
        !state.isLoading &&
        state.chapterContent.isNotEmpty &&
        isImageDominantContent(state.chapterContent);

    // [UI-fix v2.0.3 | 2026-08-08] 自动换源监听：章节加载新产生错误时，
    // autoChangeSource 开启且在线书 → 自动搜索替代书源并切换（对标原版
    // ReadBook AutoChangeSource 加载失败自动换源语义的最小路径）— Qoder
    ref.listen(readerNotifierProvider, (prev, next) {
      if (next.error != null && prev?.error == null) {
        unawaited(_maybePromptSourceLogin(next));
        _maybeAutoChangeSource(next);
      }
    });
    // 工具栏显隐时同步系统状态栏（对标原版 ReadMenu 动画回调 upSystemUiVisibility）
    ref.listen(readerNotifierProvider.select((s) => s.showControls), (
      prev,
      next,
    ) {
      if (prev != next) {
        _applySystemChrome(menuVisible: next);
      }
    });

    ref.listen(readerSettingsProvider.select((value) => value.value?.screen), (
      previous,
      next,
    ) {
      if (next != null && previous != next) _applySystemChrome();
    });

    ref.listen(
      readerSettingsProvider.select((value) => value.value?.autoPageTurn),
      (previous, next) {
        if (next != null && previous != next) _syncAutoTimer();
      },
    );

    return PopScope<Object?>(
      // [P2-30] 退出判定统一收敛到 onPopInvokedWithResult（canPop=false 使
      // 系统返回/手势返回/ Navigator.maybePop —— 阅读顶栏「返回/回书架」
      // 按钮即此路径 —— 全部先过判定函数再 pop，对齐原版 finish() 单一
      // 退出路径）。注意：裸 Navigator.pop()（应用内无此调用点）不受
      // canPop 拦截，直接 didPop=true 走兜底落库分支（保持既有行为：
      // 进度落库 + 退出，不弹窗）。
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          unawaited(notifier.saveProgress());
        } else {
          unawaited(_onExitPop(context));
        }
      },
      child: Scaffold(
        backgroundColor: state.backgroundColor,
        // F6：刘海/挖孔边距（paddingDisplayCutouts / readBodyToLh）
        body: ReaderMenuThemeHost(
          config:
              ref.watch(readerSettingsProvider).value?.menuTheme ??
              ref.read(readerSettingsRepositoryProvider).current.menuTheme,
          readingBackground: state.backgroundColor,
          readingBrightness: state.readingBrightness,
          builder: (context) {
            ref.watch(readerSettingsProvider);
            final readingSettings = ref
                .read(readerSettingsRepositoryProvider)
                .current;
            final textLayout = readingSettings.textLayout;
            final pageLayout = readingSettings.pageLayout;
            final screen = readingSettings.screen;
            final interaction = readingSettings.interaction;
            final autoPageTurn = readingSettings.autoPageTurn;
            final bodyInsets = _stableBodyInsets(context);
            final avoidTop =
                !screen.extendIntoCutout || screen.avoidDisplayCutouts;
            final avoidSides =
                !screen.extendIntoCutout || screen.avoidDisplayCutouts;
            final avoidBottom =
                !screen.hideNavigationBar || screen.avoidDisplayCutouts;
            final bottomInset = readerContentBottomInset(
              systemBottomInset: bodyInsets.bottom,
              cutoutBottomInset: _cutoutBottomInset,
              hideNavigationBar: screen.hideNavigationBar,
              paddingDisplayCutouts: screen.avoidDisplayCutouts,
            );
            final bodyPadding = EdgeInsets.only(
              top: avoidTop ? bodyInsets.top : 0,
              left: avoidSides ? bodyInsets.left : 0,
              right: avoidSides ? bodyInsets.right : 0,
              bottom: bottomInset,
            );
            final pageInsets = bodyPadding.copyWith(
              top: avoidTop || !screen.hideStatusBar ? bodyInsets.top : 0,
            );
            return Stack(
              children: [
                Positioned.fill(
                  child: MediaQuery.removeViewPadding(
                    context: context,
                    removeTop: avoidTop,
                    removeLeft: avoidSides,
                    removeRight: avoidSides,
                    removeBottom: avoidBottom,
                    child: Stack(
                      children: [
                        if (!imageDominant)
                          GestureDetector(
                            onTapUp: (details) => _handleTap(context, details),
                            child: ReaderPageView(
                              onTapUp: (details) =>
                                  _handleTap(context, details),
                              key: _pageViewKey,
                              contentInsets: pageInsets,
                              // [UI_SYNC_REFACTOR S6 修 | 2026-09-08] 用户反馈④：
                              // 阅读页头部补章节链接与书源名（书名在菜单顶栏）— Qoder
                              // [UI_SYNC_REFACTOR S6 修 | 2026-09-08] 书源名优先取 Book.originName
                              //（同步可靠），解析结果作兜底 — Qoder
                              // 排版使用共享不可变快照，渲染参数保持原单位。— Codex + UI
                              paragraphSpacing: textLayout.paragraphSpacing,
                              letterSpacing: textLayout.letterSpacing,
                              paragraphIndent: textLayout.paragraphIndent,
                              textFullJustify: textLayout.textFullJustify,
                              // [UI-fix v2.0.3 | 2026-08-06] 页面边距接入分页渲染 — Qoder
                              marginTop: pageLayout.bodyPadding.top,
                              marginBottom: pageLayout.bodyPadding.bottom,
                              marginLeft: pageLayout.bodyPadding.left,
                              marginRight: pageLayout.bodyPadding.right,
                              pageChrome: ReaderPageChromeConfig.fromSettings(
                                pageLayout,
                                hideStatusBar: screen.hideStatusBar,
                                titleFontFamily:
                                    readingSettings.titleFontFamily,
                              ),
                              readBodyToLh: screen.extendIntoCutout,
                              // [UI-fix v2.0.3 | 2026-08-08] MoreConfig 第①批：长按选择
                              // 文本开关与滚动翻页无动画接入内容区 — Qoder
                              selectText: interaction.selectText,
                              noAnimScroll: interaction.noAnimScrollPage,
                              // [UI-fix v2.0.4 | 2026-08-08] 界面面板字重/自定义文字色与
                              // MoreConfig 第②批鼠标滚轮翻页接入内容区 — Qoder
                              textBold: textLayout.textBold,
                              // [C3 斜体 | Qoder UI] 斜体透传（参考版行内面板开关）
                              italic: textLayout.italic,
                              mouseWheelPage: interaction.mouseWheelPage,
                              // [UI-fix v2.0.5 | 2026-08-10] 双页模式档位透传（对标原版
                              // doubleHorizontalPage 0-3 档）— Reasonix
                              doubleHorizontalPage:
                                  pageLayout.doubleHorizontalPage,
                              // [UI-fix v2.0.5 | 2026-08-10] 中文分行开关透传（对标原版
                              // useZhLayout）— Reasonix
                              useZhLayout: textLayout.useZhLayout,
                              // [UI-fix v2.0.5 | 2026-08-10] 段首标点悬挂透传（对标原版
                              // hangingPunctuation）— Reasonix
                              hangingPunctuation: textLayout.hangingPunctuation,
                              reviewCounts: _reviewCounts,
                              onReviewTap: _onReviewTap,
                            ),
                          ),
                        Padding(
                          padding: bodyPadding,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (imageDominant)
                                ReaderImageDominantBody(
                                  content: state.chapterContent,
                                  book: book,
                                  imageStyle: book.readConfig?.imageStyle,
                                  onToggleControls: notifier.toggleControls,
                                  hasNextChapter: state.hasNextChapter,
                                  hasPrevChapter: state.hasPreviousChapter,
                                  onNextChapter: notifier.nextChapter,
                                  onPrevChapter: notifier.prevChapter,
                                ),
                              if (!state.showControls)
                                ReaderStatusStrip(
                                  settings: readingSettings.statusStrip,
                                  hideStatusBar: screen.hideStatusBar,
                                  readBodyToLh: screen.extendIntoCutout,
                                ),
                              // [C10 对齐 | Qoder UI] 自动翻页运行时浮条：翻页进行中、菜单未展开
                              //（朗读浮条为底部另一占用方，互斥显示）时浮于正文底部，支持速度
                              // 步进与 目录/停止/设置 快捷操作（对齐参考版「即开即调」形态）
                              if (autoPageTurn.enabled &&
                                  !state.showControls &&
                                  !aloudActive)
                                Positioned(
                                  bottom: 24,
                                  left: 0,
                                  right: 0,
                                  child: Center(
                                    // 浮条自身消费点击：避免点在标签/空白处透传到正文显隐手势
                                    child: GestureDetector(
                                      onTap: () {},
                                      child: AutoTurnPanel(
                                        intervalSeconds:
                                            autoPageTurn.intervalSeconds,
                                        onIntervalChanged: _setAutoPageInterval,
                                        onStop: _toggleAutoPage,
                                        onOpenCatalog: () =>
                                            unawaited(_openToc()),
                                        onOpenSettings: () =>
                                            ReaderSettingsSheet.show(context),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // [UI_SYNC_REFACTOR S2-1] 单块底部面板（五分区，替代顶/底栏
                // 两块分立；朗读态与面板互斥显示——S2-2 将朗读条并入面板路由页）
                ReaderMenuTheme(
                  builder: (context) => aloudActive && capsule.classicExpanded
                      ? ReadAloudBar(
                          onDismiss: () => ref
                              .read(readAloudCapsuleProvider.notifier)
                              .showClassic(false),
                          onOpenCatalog: () => unawaited(_openToc()),
                          onBackstage: () {
                            ref
                                .read(readAloudCapsuleProvider.notifier)
                                .showClassic(false);
                            Navigator.of(context).maybePop();
                          },
                        )
                      : ReaderMenuPanel(
                          visible: state.showControls,
                          bottomAccessory:
                              aloudActive &&
                                  !audio.isStreamMode &&
                                  !imageDominant
                              ? ValueListenableBuilder<bool>(
                                  valueListenable: ref
                                      .read(audioNotifierProvider.notifier)
                                      .followReadAloud,
                                  builder: (context, following, _) {
                                    if (following) {
                                      return const SizedBox.shrink();
                                    }
                                    return SafeArea(
                                      top: false,
                                      bottom: false,
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          right: 16,
                                          bottom: 8,
                                        ),
                                        child: Wrap(
                                          alignment: WrapAlignment.end,
                                          spacing: 8,
                                          runSpacing: 4,
                                          children: [
                                            _readAloudPositionChip(
                                              context,
                                              icon: Icons.my_location,
                                              label: context
                                                  .l10n
                                                  .readAloudReturnToPosition,
                                              onPressed: audio.isLoading
                                                  ? null
                                                  : ref
                                                        .read(
                                                          audioNotifierProvider
                                                              .notifier,
                                                        )
                                                        .restoreReadAloudFollow,
                                            ),
                                            _readAloudPositionChip(
                                              context,
                                              icon: Icons.play_arrow,
                                              label: context
                                                  .l10n
                                                  .readAloudFromThisPage,
                                              onPressed:
                                                  state.isLoading ||
                                                      audio.isLoading
                                                  ? null
                                                  : () => unawaited(
                                                      _readFromVisiblePage(),
                                                    ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                )
                              : null,
                          onBack: () => Navigator.of(context).maybePop(),
                          onAddBookmark: () => _addBookmark(state),
                          onOpenCatalog: () => unawaited(_openToc()),
                          onOpenSettings: () =>
                              ReaderSettingsSheet.show(context),
                          onOpenContentSearch: () => _openContentSearch(state),
                          onReadAloud: _onReadAloudTap,
                          onToggleAutoPage: _toggleAutoPage,
                          onOpenReplaceRules: () => Navigator.pushNamed(
                            context,
                            AppRoutes.replaceRules,
                          ),
                          progressBehavior: interaction.progressBarBehavior,
                          onSeekPage: (page) =>
                              _pageViewKey.currentState?.goToPage(page),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _readAloudPositionChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) => ActionChip(
    avatar: Icon(
      icon,
      size: 16,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
    label: Text(label),
    labelStyle: Theme.of(context).textTheme.labelMedium,
    side: BorderSide.none,
    shape: const StadiumBorder(),
    onPressed: onPressed,
  );

  /// 从当前可见页的起点切换朗读；分页取页首，滚动取当前视口原文锚点。
  Future<void> _readFromVisiblePage() async {
    final reader = ref.read(readerNotifierProvider);
    final bookUrl = reader.currentBook?.bookUrl;
    final chapter = reader.currentChapterIndex;
    final page = _pageViewKey.currentState;
    if (reader.isLoading ||
        bookUrl == null ||
        page == null ||
        page.pageCount == 0) {
      return;
    }
    final offset = reader.pageTurnMode == PageTurnMode.scroll
        ? ref.read(readerNotifierProvider.notifier).currentSourceOffset ?? 0
        : page.currentSourceRange.$1;
    final audio = ref.read(audioNotifierProvider.notifier);
    try {
      await audio.seekToChapterPosition(chapter, offset);
      if (!mounted) return;
      final current = ref.read(audioNotifierProvider);
      if (current.bookUrl != bookUrl ||
          current.currentIndex != chapter ||
          (current.state != PlayerState.playing &&
              current.state != PlayerState.paused)) {
        return;
      }
      audio.restoreReadAloudFollow();
      if (current.state == PlayerState.paused) await audio.resumeOrPlay();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.readAloudControlFailed('$error'))),
      );
    }
  }

  // ===== 交互 =====

  /// 打开独立目录页（对标原版 ll_catalog → TocActivity）
  ///
  /// [UI-fix v2.0.4 | 2026-08-08] 目录入口由侧边抽屉改为独立目录页
  /// TocScreen（/toc 路由，传当前 Book）；页面 pop 返回选中章节原始
  /// index（int）后跳转对应章节 — Qoder
  Future<void> _openToc() async {
    final book = ref.read(readerNotifierProvider).currentBook;
    if (book == null) return;
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.toc,
      arguments: book,
    );
    if (!mounted) return;
    if (result is int) {
      await ref.read(readerNotifierProvider.notifier).goToChapter(result);
    }
  }

  /// 底栏朗读按钮点击处理
  ///
  /// [UI-fix v2.0.1 | 2026-08-06] 去除存根 SnackBar，打通朗读链路：
  /// 对标原版 ReadBookActivity.onClickReadAloud —— 朗读进行中再次点击为
  /// 播放/暂停切换并重新展开控制条；未启动时从当前章启动朗读 — Qoder
  void _onReadAloudTap() {
    final state = ref.read(readerNotifierProvider);
    final audio = ref.read(audioNotifierProvider);
    final book = state.currentBook;
    final aloudActive =
        book != null &&
        audio.bookUrl == book.bookUrl &&
        audio.state != PlayerState.idle;

    if (aloudActive) {
      final notifier = ref.read(audioNotifierProvider.notifier);
      if (audio.isPlaying) {
        notifier.pause();
      } else {
        unawaited(notifier.resumeOrPlay());
      }
      ref.read(readAloudCapsuleProvider.notifier).showClassic(true);
      return;
    }
    unawaited(_startReadAloud(state));
  }

  /// 菜单与浮条通过共享仓储启停，计时器订阅同一配置。
  Future<void> _toggleAutoPage() => _saveAutoPageTurn(
    () => ref
        .read(readerSettingsRepositoryProvider)
        .updateAutoPageTurn(
          enabled: !ref
              .read(readerSettingsRepositoryProvider)
              .current
              .autoPageTurn
              .enabled,
        ),
  );

  Future<void> _setAutoPageInterval(double seconds) => _saveAutoPageTurn(
    () => ref
        .read(readerSettingsRepositoryProvider)
        .updateAutoPageTurn(intervalSeconds: seconds),
  );

  Future<void> _saveAutoPageTurn(Future<void> Function() update) async {
    try {
      await update();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('自动翻页设置保存失败，请重试')));
      }
    }
  }

  /// 启动当前书的朗读（链路：AudioNotifier.startReadAloud → play → audioSpeak）
  Future<void> _startReadAloud(ReaderState state) async {
    final book = state.currentBook;
    if (book == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('无法启动朗读：未打开书籍')));
      return;
    }
    ref.read(readAloudCapsuleProvider.notifier).showClassic(false);
    await ref
        .read(audioNotifierProvider.notifier)
        .startReadAloud(
          bookUrl: book.bookUrl,
          bookName: book.name,
          chapterIndex: state.currentChapterIndex,
          startChapterPos: ref
              .read(readerNotifierProvider.notifier)
              .currentSourceOffset,
        );
  }

  /// 根据点击区域配置执行对应功能
  void _handleTap(BuildContext context, TapUpDetails details) {
    final notifier = ref.read(readerNotifierProvider.notifier);
    // 菜单打开时正文点击只关闭菜单，优先于选区、边缘死区和翻页分区。
    if (ref.read(readerNotifierProvider).showControls) {
      notifier.hideControls();
      return;
    }
    if (_pageViewKey.currentState?.consumeSelectionTap() ?? false) return;
    final pageView = _pageViewKey.currentState;
    final body = _pageViewKey.currentContext?.findRenderObject();
    if (body is! RenderBox || !body.hasSize) return;
    final action = readerTapActionForPosition(
      ref.read(readerSettingsRepositoryProvider).current.interaction,
      body.globalToLocal(details.globalPosition),
      body.size,
    );

    switch (action) {
      case TapAction.none:
        break;
      case TapAction.prevPage:
        // [UI-fix v2.0.3 | 2026-08-06] 直接驱动 PageView 翻页（见下方根因说明）— Qoder
        pageView?.prevPageOrChapter();
      case TapAction.nextPage:
        pageView?.nextPageOrChapter();
      case TapAction.toggleControls:
        notifier.toggleControls();
      case TapAction.openCatalog:
        unawaited(_openToc());
    }
  }

  // [UI-fix v2.0.3 | 2026-08-06] 修复点击翻页失效回归 —— Qoder
  // 根因：此前点击翻页经 ReaderNotifier.nextGlobalPage/prevGlobalPage 仅更新
  // 全局页索引状态（globalPageIndex/currentChapterPos），却未驱动 ReaderPageView
  // 内部的 PageController；且「globalPageIndex 未变才回退章级翻页」的判定在同章
  // 翻页时永不成立（同章翻页必然改变 globalPageIndex），导致点击后视觉上不翻页。
  // 现改为在 _handleTap 中直接调用 ReaderPageView.next/prevPageOrChapter()：
  // 既驱动 PageController 完成各模式（仿真/滑动/覆盖/无动画/滚动）视觉翻页与
  // 跨章无缝切换，又经其内部 updatePosition() 同步全局页码指示器。

  /// 添加书签（提取当前章节内容前 100 字符作为摘要）
  void _addBookmark(ReaderState state) {
    final book = state.currentBook;
    final chapter = state.currentChapter;
    if (book == null || chapter == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('无法添加书签：未打开书籍')));
      return;
    }
    final content = state.chapterContent;
    final summary = content.length > 100 ? content.substring(0, 100) : content;

    ref
        .read(bookmarkNotifierProvider.notifier)
        .addBookmark(
          bookName: book.name,
          bookAuthor: book.author,
          chapterIndex: state.currentChapterIndex,
          chapterPos: 0,
          chapterName: chapter.title,
          bookText: summary,
        );
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('已添加书签：${chapter.title}')));
  }

  /// 打开正文搜索页面
  void _openContentSearch(ReaderState state) {
    final book = state.currentBook;
    if (book == null) return;
    Navigator.pushNamed(context, AppRoutes.searchContent, arguments: book);
  }

  /// 进入完整阅读设置，返回后同步系统显示与自动翻页。
  // ===== [UI-fix v2.0.3 | 2026-08-08] 自动换源最小路径 =====
  // 对标原版 ReadBook 内容加载失败后 AutoChangeSource 按书名搜替代源并切换：
  // 复用 searchSource/switchSource FFI（与换源页同源链路）；完整重试策略/
  // 失败源禁用等复杂逻辑留待后续批次 — Qoder

  /// loginCheckJs 判定未登录时自动拉起登录页（§5.14-18）
  Future<void> _maybePromptSourceLogin(ReaderState state) async {
    if (!isSourceLoginRequiredError(state.error)) return;
    final book = state.currentBook;
    if (book == null) return;
    if (book.origin == BookType.localTag ||
        book.origin.startsWith(BookType.webDavTag)) {
      return;
    }
    BookSource? source;
    try {
      final sources = await ref
          .read(bookSourceRepositoryProvider)
          .getBookSources();
      for (final s in sources) {
        if (s.bookSourceUrl == book.origin) {
          source = s;
          break;
        }
      }
    } catch (_) {
      return;
    }
    if (!mounted || source == null) return;
    await promptSourceLoginIfNeeded(
      context,
      error: state.error,
      source: source,
    );
  }

  /// 章节加载失败时尝试自动换源（在线书且开关开启时）
  void _maybeAutoChangeSource(ReaderState state) {
    if (!ref.read(readerSettingsRepositoryProvider).current.autoChangeSource) {
      return;
    }
    if (_autoSwitching) return;
    final book = state.currentBook;
    if (book == null) return;
    // 本地书/WebDAV 书无书源可换（对标原版仅网络书自动换源）
    if (book.origin == BookType.localTag ||
        book.origin.startsWith(BookType.webDavTag)) {
      return;
    }
    if (_autoSwitchBookUrl != book.bookUrl) {
      _autoSwitchBookUrl = book.bookUrl;
      _autoSwitchAttempts = 0;
    }
    if (_autoSwitchAttempts >= _autoSwitchMaxAttempts) return;
    _autoSwitchAttempts++;
    unawaited(_doAutoChangeSource(book));
  }

  /// 执行自动换源：搜索替代书源 → 取首个非同源候选 → switchSource → 重开书
  Future<void> _doAutoChangeSource(Book book) async {
    _autoSwitching = true;
    try {
      final service = ref.read(sourceSwitchServiceProvider);
      final matches = await service.searchSource(book.name, book.author);
      SourceMatch? target;
      for (final m in matches) {
        if (m.sourceUrl.isNotEmpty && m.sourceUrl != book.origin) {
          target = m;
          break;
        }
      }
      if (!mounted) return;
      if (target == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('自动换源：无可用替代书源')));
        return;
      }
      final switched = await service.switchSource(
        book.bookUrl,
        target.sourceUrl,
        target.bookUrl,
      );
      if (!mounted) return;
      // 采用事务返回的源信息，保留当前阅读会话的原文位置。
      final updated = switched.copyWith(
        durChapterIndex: book.durChapterIndex,
        durChapterPos: book.durChapterPos,
        durChapterTitle: book.durChapterTitle,
      );
      final notifier = ref.read(readerNotifierProvider.notifier);
      notifier.updateCurrentBook(updated);
      await notifier.openBook(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('章节加载失败，已自动换源：${target.sourceName}')),
      );
      // 换源成功后重置尝试计数（新书源可再次触发）
      _autoSwitchAttempts = 0;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('自动换源失败: $e')));
      }
    } finally {
      _autoSwitching = false;
    }
  }
}
