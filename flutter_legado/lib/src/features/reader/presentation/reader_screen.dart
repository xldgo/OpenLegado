import '../../../app/routing/app_navigation.dart';
import '../../../app/routing/route_arguments.dart';
import 'views/reader_content_viewport.dart';
import '../application/reader_exit_controller.dart';
import '../application/reader_keep_awake_controller.dart';
import 'overlays/reader_add_to_shelf_dialog.dart';
import '../application/reader_chapter_coordinator.dart';
import '../application/reader_source_recovery_controller.dart';

import '../../../providers/chapter_content_provider.dart';
import '../../../providers/download_settings_provider.dart';
import '../../book_sources/book_source_repository_provider.dart';
import '../../../providers/change_source/source_switch_dependencies.dart';
import '../../../providers/book_content_provider.dart';
import '../application/reader_settings_provider.dart';
import '../../../domain/models/reader_interaction_settings.dart';
import '../../../widgets/reader/reader_tap_hit_test.dart';
import '../../../app/session/reader_theme_session.dart';

import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../../../l10n/app_localization.dart';
import '../../audio/application/audio_notifier.dart';
import '../../bookmarks/bookmarks.dart';
import '../../bookshelf/bookshelf.dart';
import '../../../providers/general_settings_provider.dart';
import '../../../providers/screen_awake_provider.dart';
import '../application/reader_notifier.dart';
import '../../../providers/theme/system_bar_controller.dart';
import '../../../app/routing/route_names.dart';
import '../../../services/system_brightness.dart';
import '../../../services/system_bar_service.dart';
import '../../../platform/display/display_corners.dart';
import '../../../platform/display/display_cutout_insets.dart';
import '../../../utils/app_route_observer.dart';
import '../../audio/application/read_aloud_capsule.dart';
import '../../../widgets/reader/auto_turn_panel.dart';
import '../../../widgets/reader/reader_page_view.dart';
import 'overlays/reader_settings_sheet.dart';
import 'overlays/reader_controls_overlay.dart';
import '../../../widgets/reader/reader_menu_theme.dart';
import '../../../widgets/reader/review_detail_sheet.dart';
import '../application/reader_presentation_provider.dart';
import '../../../utils/source_login_prompt.dart';

/// 阅读器页面：系统显示、交互调度与组件组合。
///
/// 状态由 [ReaderNotifier] 管理；分页/翻页渲染由 [ReaderPageView] 承担；
/// 工具栏与设置由本Feature浮层组合，正文与状态栏沿用已有组件。
/// 章节附加任务、书源恢复与退出策略由控制器承担，页面保留现有UI生命周期。
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
  late final ReaderKeepAwakeController _keepAwake;
  bool _appResumed = true;
  final GlobalKey<ReaderPageViewState> _pageViewKey =
      GlobalKey<ReaderPageViewState>();

  Size? _insetViewportSize;
  EdgeInsets _bodySystemInsets = EdgeInsets.zero;
  double? _cutoutPixelRatio;
  DisplayCutoutInsets? _cutoutInsets;
  DisplayCorners? _displayCorners;
  int _cutoutGeneration = 0;

  /// 保存系统栏原始尺寸；配置变化重算占位，菜单临时显隐不改变布局。
  EdgeInsets _stableBodyInsets(BuildContext context) {
    final media = MediaQuery.of(context);
    if (_insetViewportSize != media.size ||
        _cutoutPixelRatio != media.devicePixelRatio) {
      _insetViewportSize = media.size;
      _cutoutPixelRatio = media.devicePixelRatio;
      _bodySystemInsets = media.viewPadding;
      _cutoutInsets = null;
      _displayCorners = null;
      unawaited(
        _loadDisplayGeometry(++_cutoutGeneration, media.devicePixelRatio),
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

  Future<void> _loadDisplayGeometry(int generation, double pixelRatio) async {
    final values = await Future.wait<Object?>([
      SystemBarService.displayCutoutInsets(pixelRatio),
      SystemBarService.displayCorners(pixelRatio),
    ]);
    if (!mounted || generation != _cutoutGeneration) return;
    final cutout = values[0] as DisplayCutoutInsets?;
    final corners = values[1] as DisplayCorners?;
    final viewport = _insetViewportSize!;
    final currentCorners =
        corners != null &&
            (corners.size.width - viewport.width).abs() <= 1 &&
            (corners.size.height - viewport.height).abs() <= 1
        ? corners
        : null;
    final currentCutout = cutout != null && cutout.matches(viewport)
        ? cutout
        : null;
    if (currentCutout != _cutoutInsets || currentCorners != _displayCorners) {
      setState(() {
        _cutoutInsets = currentCutout;
        _displayCorners = currentCorners;
      });
    }
  }

  /// 自动翻页定时器
  Timer? _autoTimer;

  late final ReaderChapterCoordinator _chapters;
  late final ReaderSourceRecoveryController _sourceRecovery;

  bool _settingsLoaded = false;

  late final ReaderExitController _exit;
  late final ReaderThemeSession _themeSession;

  @override
  void initState() {
    super.initState();
    _appResumed =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _keepAwake = ReaderKeepAwakeController(ref.read(screenAwakeProvider));
    _syncKeepAwake();
    _themeSession = ref.read(readerThemeSessionProvider)..reset();
    _systemBars = ref.read(systemBarControllerProvider);
    _chapters = ReaderChapterCoordinator(
      content: ref.read(chapterContentServiceProvider),
      settings: ref.read(downloadSettingsRepositoryProvider),
      sources: ref.read(bookSourceRepositoryProvider),
      reviews: ref.read(reviewServiceProvider),
    )..observe(ref.read(readerNotifierProvider));
    _chapters.addListener(_onReviewChanged);
    _sourceRecovery = ReaderSourceRecoveryController(
      host: ReaderSourceRecoveryHost(
        readState: () => ref.read(readerNotifierProvider),
        openBook: (book) async {
          final notifier = ref.read(readerNotifierProvider.notifier);
          notifier.updateCurrentBook(book);
          await notifier.openBook(book);
        },
        notify: (message) {
          if (!mounted) return;
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(message)));
        },
      ),
      settings: ref.read(readerSettingsRepositoryProvider),
      sources: ref.read(bookSourceRepositoryProvider),
      switchSource: ref.read(sourceSwitchServiceProvider),
    );
    _exit = ReaderExitController(
      host: ReaderExitHost(
        readBook: () => ref.read(readerNotifierProvider).currentBook,
        isActive: () => mounted,
        confirmAdd: (name) => showReaderAddToShelfDialog(context, name),
        addBook: (book) async {
          final ok = await ref
              .read(bookshelfNotifierProvider.notifier)
              .addBook(book);
          if (ok) return null;
          if (!mounted) return '加入书架失败';
          final error = ref.read(bookshelfNotifierProvider).error;
          return error == null ? '加入书架失败' : '加入书架失败：$error';
        },
        saveProgress: () =>
            ref.read(readerNotifierProvider.notifier).saveProgress(),
        close: () => Navigator.pop(context),
        notify: (message) {
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(message)));
          }
        },
      ),
      bookshelf: ref.read(bookshelfRepositoryProvider),
      settings: ref.read(generalSettingsRepositoryProvider),
    );
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
    _keepAwake.dispose();
    _chapters.removeListener(_onReviewChanged);
    _chapters.dispose();
    _sourceRecovery.dispose();
    _exit.dispose();
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
    _syncKeepAwake();
    _applySystemChrome();
  }

  @override
  void didPopNext() {
    _readerRouteActive = true;
    _syncKeepAwake();
    _applySystemChrome();
  }

  @override
  void didPushNext() {
    _readerRouteActive = false;
    _syncKeepAwake();
    _systemBars.releaseReader(_systemBarOwner);
  }

  @override
  void didPop() {
    _readerRouteActive = false;
    _syncKeepAwake();
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
    _appResumed = state == AppLifecycleState.resumed;
    _syncKeepAwake();
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

  void _syncKeepAwake() {
    _keepAwake.configure(
      ref
          .read(readerSettingsRepositoryProvider)
          .current
          .screen
          .keepScreenOnSeconds,
    );
    _keepAwake.setVisible(_readerRouteActive && _appResumed);
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
      if (mounted) {
        _applySystemChrome();
        _syncKeepAwake();
      }
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

    _keepAwake.onInteraction();
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

  void _onReviewChanged() {
    if (mounted) setState(() {});
  }

  void _onReviewTap(int paragraphIndex, int count) {
    final state = ref.read(readerNotifierProvider);
    final book = state.currentBook;
    final chapter = state.currentChapter;
    final summary = _chapters.value;
    if (!summary.belongsTo(state)) return;
    final sourceJson = summary.sourceJson;
    if (book == null || chapter == null || sourceJson == null) return;
    final paraData = summary.keys[paragraphIndex] ?? '$paragraphIndex';
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

  @override
  Widget build(BuildContext context) {
    ref.watch(readerScreenDependenciesProvider);
    final state = ref.read(readerNotifierProvider);
    final notifier = ref.read(readerNotifierProvider.notifier);
    final aloudActive = ref.watch(readerReadAloudActiveProvider);
    final imageDominant =
        state.currentBook != null &&
        !state.isLoading &&
        ref.watch(readerImageDominantProvider);

    // [UI-fix v2.0.3 | 2026-08-08] 自动换源监听：章节加载新产生错误时，
    // autoChangeSource 开启且在线书 → 自动搜索替代书源并切换（对标原版
    // ReadBook AutoChangeSource 加载失败自动换源语义的最小路径）— Qoder
    ref.listen(readerNotifierProvider, (prev, next) {
      _chapters.observe(next);
      if (next.error != null && prev?.error == null) {
        unawaited(_maybePromptSourceLogin(next));
        unawaited(_sourceRecovery.onChapterError(next));
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
      if (next != null && previous != next) {
        _applySystemChrome();
        _keepAwake.configure(next.keepScreenOnSeconds);
      }
    });

    ref.listen(
      readerSettingsProvider.select((value) => value.value?.autoPageTurn),
      (previous, next) {
        if (next != null && previous != next) _syncAutoTimer();
      },
    );

    return PopScope<Object?>(
      // [P2-30] 退出判定统一收敛到 ReaderExitController（canPop=false 使
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
          unawaited(_exit.requestExit());
        }
      },
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _keepAwake.onInteraction(),
        onPointerUp: (_) => _keepAwake.onInteraction(),
        onPointerSignal: (_) => _keepAwake.onInteraction(),
        child: Scaffold(
          backgroundColor: state.backgroundColor,
          // 输入面板自行避让键盘，正文保持原视口，避免键盘开关触发重分页。
          resizeToAvoidBottomInset: false,
          // 系统栏占位与四向缺口分别采样，再统一交给内容视口。
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
              return Stack(
                children: [
                  ReaderContentViewport(
                    state: state,
                    readingSettings: readingSettings,
                    bodyInsets: _stableBodyInsets(context),
                    cutoutInsets: _cutoutInsets,
                    displayCorners: _displayCorners,
                    pageViewKey: _pageViewKey,
                    imageDominant: imageDominant,
                    reviewCounts: _chapters.value.counts,
                    onTapUp: (details) => _handleTap(context, details),
                    onReviewTap: _onReviewTap,
                    onToggleControls: notifier.toggleControls,
                    onNextChapter: notifier.nextChapter,
                    onPreviousChapter: notifier.prevChapter,
                    autoTurnPanel:
                        readingSettings.autoPageTurn.enabled &&
                            !state.showControls &&
                            !aloudActive
                        ? Positioned(
                            bottom: 24,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: GestureDetector(
                                onTap: () {},
                                child: AutoTurnPanel(
                                  intervalSeconds: readingSettings
                                      .autoPageTurn
                                      .intervalSeconds,
                                  onIntervalChanged: _setAutoPageInterval,
                                  onStop: _toggleAutoPage,
                                  onOpenCatalog: () => unawaited(_openToc()),
                                  onOpenSettings: () =>
                                      ReaderSettingsSheet.show(context),
                                ),
                              ),
                            ),
                          )
                        : null,
                  ),
                  ReaderControlsOverlay(
                    state: state,
                    imageDominant: imageDominant,
                    progressBehavior:
                        readingSettings.interaction.progressBarBehavior,
                    onAddBookmark: () => _addBookmark(state),
                    onOpenCatalog: () => unawaited(_openToc()),
                    onOpenContentSearch: () => _openContentSearch(state),
                    onReadAloud: _onReadAloudTap,
                    onToggleAutoPage: _toggleAutoPage,
                    onReadFromVisiblePage: _readFromVisiblePage,
                    onSeekPage: (page) =>
                        _pageViewKey.currentState?.goToPage(page),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

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
    final result = await GoRouter.of(context)
        .pushAppRoute(AppRoutes.toc, extra: book);
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
    GoRouter.of(context).pushAppRoute(
      AppRoutes.searchContent,
      extra: ContentSearchRouteArgs(book: book),
    );
  }

  /// loginCheckJs 判定未登录时自动拉起登录页（§5.14-18）
  Future<void> _maybePromptSourceLogin(ReaderState state) async {
    if (!isSourceLoginRequiredError(state.error)) return;
    final book = state.currentBook;
    if (book == null) return;
    final source = await _sourceRecovery.findLoginSource(book);
    if (!mounted || source == null) return;
    await promptSourceLoginIfNeeded(
      context,
      error: state.error,
      source: source,
    );
  }
}
