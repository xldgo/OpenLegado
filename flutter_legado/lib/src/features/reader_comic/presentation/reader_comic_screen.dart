import '../../../app/routing/app_navigation.dart';
import '../../../theme/app_motion.dart';
import '../application/comic_settings_controller.dart';
import '../application/comic_image_actions_service.dart';
import '../data/plugin_comic_image_actions_platform.dart';
import 'views/comic_webtoon_view.dart';
import '../application/comic_preload_service.dart';
import '../application/comic_reader_controller.dart';
import '../application/comic_reader_state.dart';
import 'views/comic_image_item.dart';
import '../../bookshelf/bookshelf_repositories.dart';
import '../../../providers/reading_provider.dart';
import '../../book_sources/book_source_repository_provider.dart';
import '../../../providers/book_content_provider.dart';
import '../../../providers/config_settings_provider.dart';
import '../../../domain/models/manga_settings.dart';

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../../../providers/network_provider.dart';

import '../../../models/models.dart';
import '../../../app/routing/route_names.dart';
import '../../../providers/media_provider.dart';
import '../../../services/platform_bridge_service.dart';
import '../../../services/system_brightness.dart';
import '../../../widgets/loading_indicator.dart';
import '../../../widgets/error_view.dart';
import 'overlays/manga_config_sheet.dart';
import '../../../models/manga_auto_read.dart';
import 'overlays/manga_catalog_sheet.dart';
import '../../../models/manga_click_actions.dart';
import 'overlays/manga_menu.dart';
import 'views/manga_paged_view.dart';
import 'overlays/manga_page_actions_sheet.dart';
import '../../../models/manga_page_scale_type.dart';
import '../../../models/manga_scroll_mode.dart';

/// 漫画阅读页面
///
/// 支持纵向连续滚动、双指缩放、前后图片预加载。
/// 通过 [bookUrl] 参数接收书籍标识，经 ReadingRepository 获取章节与图片列表。
class ReaderComicScreen extends ConsumerStatefulWidget {
  /// 书籍 URL 标识
  final String bookUrl;

  const ReaderComicScreen({super.key, required this.bookUrl});

  @override
  ConsumerState<ReaderComicScreen> createState() => _ReaderComicScreenState();
}

class _ReaderComicScreenState extends ConsumerState<ReaderComicScreen>
    with SingleTickerProviderStateMixin {
  /// 滚动控制器，用于纵向连续滚动
  final ScrollController _scrollController = ScrollController(
    keepScrollOffset: false,
  );
  final _webtoonAnchors = ComicWebtoonAnchorController();
  int _firstVisiblePageIndex = 0;
  int _lastVisiblePageIndex = 0;

  late final ComicReaderController _reader;
  late ComicReaderState _observedSession;

  Book? get _book => _reader.state.book;
  String get _activeBookUrl => _reader.state.bookUrl;
  List<BookChapter> get _chapters => _reader.state.chapters;
  int get _currentChapterIndex => _reader.state.chapterIndex;
  List<String> get _imageUrls => _reader.state.imageUrls;
  bool get _loading => _reader.state.loading;
  String? get _error => _reader.state.error;
  Map<String, String> get _imageHeaders => _reader.state.imageHeaders;
  BookSource? get _bookSource => _reader.state.source;
  int get _loadSeq => _reader.state.navigationId;
  bool get _errorChapterLevel => _reader.state.chapterError;

  /// 是否显示控制栏（顶部返回 + 底部进度条）
  bool _showControls = false;
  bool _pageZoomed = false;

  /// [P4-3 M1] 菜单（顶栏/底栏）显隐动画控制器：
  /// 顶栏自上滑入、底栏自下滑入 + 淡入；隐藏时反向播放，**动画落定后
  /// 菜单子树从树中移除**（build 的 AnimatedBuilder 在动画结束帧返回
  /// SizedBox.shrink），保证隐藏态 `find.text(书名)` findsNothing
  /// （测试确定性，对齐既有 click_actions 用例的显隐断言）。
  late final AnimationController _menuCtrl;

  /// [P4-3 M1] 顶栏滑动（-1 → 0）
  late final Animation<Offset> _topBarPos;

  /// [P4-3 M1] 底栏滑动（1 → 0）
  late final Animation<Offset> _bottomBarPos;

  /// [P4-3 M1] 菜单淡入淡出
  late final CurvedAnimation _menuOpacity;

  /// 图片加载失败的索引集合（用于显示重试按钮）
  final Set<int> _failedIndices = {};

  /// 预加载缓存（前后各 2 页）
  static const int _preloadRange = 2;

  late final ComicSettingsController _settings;
  late final ComicImageActionsService _imageActions;
  late MangaSettings _observedSettings;
  int _appliedScrollMode = MangaScrollModes.defaultValue;
  bool _platformSettingsApplied = false;

  MangaSettings get _config => _settings.current;
  MangaColorFilterConfig get _colorFilter => _config.colorFilter;
  MangaFooterConfig get _footerConfig => _config.footer;
  bool get _enableEInk => _config.enableEInk;
  bool get _enableGray => _config.enableGray;
  int get _eInkThreshold => _config.eInkThreshold;
  int get _scrollMode => _settings.scrollMode(_book?.readConfig);
  int get _sidePadding => _settings.sidePadding(_book?.readConfig);
  int get _globalScrollMode => _config.scrollMode;
  int get _globalSidePadding => _config.sidePadding;
  int? get _bookScrollMode =>
      ComicSettingsController.bookScrollMode(_book?.readConfig);
  int? get _bookSidePadding =>
      ComicSettingsController.bookSidePadding(_book?.readConfig);
  int get _autoReadSpeed => _config.autoReadSpeed;
  int get _pageScaleType => _config.pageScaleType;
  List<int> get _clickActions => _config.clickActions;
  bool get _disableClickScroll => _config.disableClickScroll;
  bool get _disableMangaScale => _config.disableMangaScale;
  bool get _disableMangaPageAnim => _config.disableMangaPageAnim;
  bool get _hideMangaTitle => _config.hideMangaTitle;
  bool get _volumeKeyPage => _config.volumeKeyPage;
  bool get _reverseVolumeKeyPage => _config.reverseVolumeKeyPage;
  bool get _mangaLongClickSaveImage => _config.longClickSaveImage;
  bool get _disableMangaCrossFade => _config.disableCrossFade;
  int get _mangaBgColor => _config.backgroundColor;

  /// 页脚用「当前可见页」近似索引（滚动估算）
  int _visiblePageIndex = 0;

  /// [P4-3 E1] 单页式 PageController（模式/章节/初始页变化时重建）
  PageController? _pagedController;

  /// [P4-3 E1] 控制器当前规格（轴/是否右起/所属代数），用于判定是否需重建
  Axis _pagedAxis = Axis.horizontal;
  bool _pagedReversed = false;
  int _pagedGen = 0;

  /// [P4-3 E5] 点击按下位置（tap-up 时换算位移，区分点击与滑动/缩放意图）
  Offset? _tapDownPosition;

  /// [P4-3 E3] 自动翻页/自动滚动开关（会话态，不落库——对齐参考版
  /// MangaReaderContract L44 autoReadEnabled 默认 false 的会话态语义）
  bool _autoRead = false;

  /// [P4-3 E3] 自动翻页定时器（单页式每 速度×1s 翻一页；条漫每周期
  /// ceil(16/速度×10000)ms 滚动 10000px，见 [MangaAutoRead] 取证注释）
  Timer? _autoReadTimer;

  /// [P4-3 W2-fix P1-1②] 自动翻页切章挂起标志：条漫到章末排定 500ms
  /// 延迟切章期间定时器仍在 tick，用本标志防止重复排定导致连跳多章；
  /// 延迟回调内复位（对齐参考版 while 循环逐周期串行、不重入语义）
  bool _autoReadChapterPending = false;

  /// [P4-3 W2-fix ⑬] 条漫自动滚动「在飞」滚动 future 及其目标像素：
  /// 记录最近一次 [ScrollPosition.animateTo] 的完成 future 与滚动目标。
  /// 周期 tick 在「滚向章末」的在飞滚动尚未落定时不重启（守卫），滚动
  /// **完成回调**（whenComplete）里复检章末并**当下**调度切章（对齐
  /// 参考版 MangaReaderScreen L688-699：animateScrollBy 挂起至动画结束
  /// 立即检查 consumed<1 → NextChapter + delay(500L)，不等下一个周期
  /// tick，修低速时章尾多等一整周期的停留 QA ⑬ ≥90s）。中段滚动
  ///（目标 < 章末）不触发守卫，逐周期续滚保持连续（参考版 10000px/周期
  /// 100% 占空）。
  Future<void>? _webtoonScrollFuture;
  double? _webtoonScrollTarget;

  /// [P4-3 W2-fix ⑬] 上述在飞滚动是否尚未落定（future 的 whenComplete
  /// 未触发）：仅由最新 future 的完成回调清除（identical 判定），被新
  /// 滚动顶替的旧 future 完成时不会误清新滚动的在飞标记。
  bool _webtoonScrollInFlight = false;

  /// [P4-3 W2-fix P2-1] 长按页操作底栏是否打开（对齐参考版 LaunchedEffect
  /// 依赖 activeSheet：底栏打开期间自动翻页暂停）
  bool _pageActionsOpen = false;

  /// [P4-3 E2] 图片渲染 BoxFit：单页式按适配类型映射（Screen L1463-1472）；
  /// 条漫恒 fitWidth（Screen L1568）
  BoxFit get _imageFit => MangaScrollModes.isPaged(_scrollMode)
      ? MangaPageScaleType.fitFor(type: _pageScaleType)
      : MangaPageScaleType.webtoonFit;

  @override
  void initState() {
    super.initState();
    _reader = ComicReaderController(
      bookUrl: widget.bookUrl,
      bookshelf: ref.read(bookshelfRepositoryProvider),
      reading: ref.read(readingRepositoryProvider),
      sources: ref.read(bookSourceRepositoryProvider),
      preloader: ComicPreloadService(
        images: ref.read(bookImageRepositoryProvider),
        localBooks: ref.read(localBookServiceProvider),
        reading: ref.read(readingRepositoryProvider),
      ),
    );
    _settings = ComicSettingsController(
      ref.read(mangaSettingsRepositoryProvider),
    );
    _observedSettings = _settings.current;
    _settings.addListener(_onSettingsChanged);
    _imageActions = ComicImageActionsService(
      images: ref.read(bookImageRepositoryProvider),
      localBooks: ref.read(localBookServiceProvider),
      platform: const PluginComicImageActionsPlatform(),
    );
    _observedSession = _reader.state;
    _reader.addListener(_onReaderChanged);
    // [P4-3 M1] 菜单显隐动画（200ms，对齐既有 300ms 翻页动画的快显隐档位）
    _menuCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    final curve = CurvedAnimation(parent: _menuCtrl, curve: Curves.easeOut);
    _topBarPos = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(curve);
    _bottomBarPos = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(curve);
    _menuOpacity = curve;
    unawaited(_loadMangaConfig());
    unawaited(_loadBook());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) _menuCtrl.value = _showControls ? 1 : 0;
  }

  @override
  void dispose() {
    unawaited(_saveProgress());
    _reader.removeListener(_onReaderChanged);
    _reader.dispose();
    _settings.removeListener(_onSettingsChanged);
    _settings.dispose();
    _scrollController.dispose();
    // [P4-3 E3] 取消自动翻页定时器
    _autoReadTimer?.cancel();
    // [P4-3 M1] 菜单显隐动画控制器
    _menuOpacity.dispose();
    _menuCtrl.dispose();
    // [P4-3 E1] 单页式控制器（此时元素树已卸载，控制器已解绑，可安全释放）
    _pagedController?.dispose();
    // [P4-3 M5] 音量键捕获注销：退出阅读器立即关闭，防拦截范围
    // 外泄到其它页面（系统音量键恢复默认行为）
    final bridge = PlatformBridgeService.instance;
    bridge.unregisterVolumeKeyHandler();
    unawaited(bridge.setVolumeKeyCapture(false));
    unawaited(
      SystemBrightness.setFollowSystem(true).catchError((Object error) {
        debugPrint('退出漫画阅读时恢复系统亮度失败: $error');
      }),
    );
    super.dispose();
  }

  Future<void> _loadMangaConfig() async {
    if (!await _settings.load() || !mounted) return;
    _platformSettingsApplied = true;
    _syncVolumeKeyCapture();
    await _applyBrightness(_colorFilter.l);
  }

  /// 设置变化只在这里触发视口、平台和计时器副作用。
  void _onSettingsChanged() {
    if (!mounted) return;
    final previous = _observedSettings;
    final next = _settings.current;
    _observedSettings = next;
    final modeChanged = _appliedScrollMode != _scrollMode;
    _appliedScrollMode = _scrollMode;
    setState(() {});
    if (modeChanged) _applyScrollMode();
    if (modeChanged || previous.autoReadSpeed != next.autoReadSpeed) {
      _restartAutoReadTimer();
    }
    if (_platformSettingsApplied &&
        previous.volumeKeyPage != next.volumeKeyPage) {
      _syncVolumeKeyCapture();
    }
    if (_platformSettingsApplied &&
        previous.colorFilter.l != next.colorFilter.l) {
      unawaited(_applyBrightness(next.colorFilter.l));
    }
  }

  /// [P4-3 E3] 打开/关闭自动翻页（会话态，不持久化）
  ///
  /// 对齐参考版 MangaReaderContract L44（autoReadEnabled 会话态）+
  /// 原版 ReadMangaActivity L570-591 开关互斥语义（条漫自动滚动与
  /// 单页自动翻页共用同一开关与速度档，本实现以翻页模式区分两态）。
  /// 「再点停止」：再调一次（enabled=false）即取消定时器。
  void _setAutoReadEnabled(bool enabled) {
    if (enabled == _autoRead) return;
    if (mounted) setState(() => _autoRead = enabled);
    _restartAutoReadTimer();
  }

  /// [P4-3 M5] 音量键捕获同步：仅阅读器活跃且开关开启时启用捕获
  /// （对齐原版 ReadMangaActivity.onKeyDown L894-902 的阅读器内
  /// 拦截语义；壳侧 onKeyDown 捕获后经 legado/reader_keys 通道回发）
  void _syncVolumeKeyCapture() {
    final bridge = PlatformBridgeService.instance;
    if (_volumeKeyPage) {
      bridge.registerVolumeKeyHandler(_handleVolumeKey);
      unawaited(bridge.setVolumeKeyCapture(true));
    } else {
      bridge.unregisterVolumeKeyHandler();
      unawaited(bridge.setVolumeKeyCapture(false));
    }
  }

  /// [P4-3 M5] 音量键事件：up=上一页、down=下一页（对齐原版
  /// scrollToPrev/scrollToNext），反转开关交换方向；走九区点击同一
  /// 导航链 [_stepPage]（条漫滚动/单页翻页自然适配，边界与点击一致）
  Future<void> _handleVolumeKey(String direction) async {
    if (!mounted || !_volumeKeyPage) return;
    final forward = direction == 'down';
    final next = _reverseVolumeKeyPage ? !forward : forward;
    _stepPage(next ? 1 : -1);
  }

  Future<void> _persistBookScrollMode(int? value) async {
    final normalized = value == null
        ? null
        : MangaScrollModes.valid.contains(value)
        ? value
        : MangaScrollModes.defaultValue;
    await _reader.updateReadConfigField('mangaScrollMode', normalized);
  }

  Future<void> _persistBookSidePadding(int? value) => _reader
      .updateReadConfigField('webtoonSidePaddingDp', value?.clamp(0, 45));

  /// [P4-3 E3] 启动/重启自动翻页定时器（关闭或开关态为 false 时不排程）
  ///
  /// 取证（参考版 MangaReaderScreen）：
  /// - 单页式 L200-216：循环 delay(速度×1000L) → PageStep(1)；
  /// - 条漫 L677-699：每周期 tween(ceil(16/速度×10000)ms) 滚 10000px，
  ///   到章末（consumed < 1）→ delay(500L) 后 NextChapter。
  /// 参考版 LaunchedEffect 依赖 menuVisible/activeSheet——控制栏/设置面板
  /// 打开期间自动翻页暂停，关闭后从新周期恢复 → 本实现以 [_showControls]
  /// 守卫跳过 tick（设置面板打开时控制栏必然可见，单一守卫覆盖两态），
  /// 并在控制栏收起时 [_restartAutoReadTimer] 重排（对齐 LaunchedEffect
  /// 依赖变化重建语义，恢复后先走满一个完整间隔）。
  void _restartAutoReadTimer() {
    _autoReadTimer?.cancel();
    _autoReadTimer = null;
    if (!_autoRead) return;
    final period = MangaScrollModes.isPaged(_scrollMode)
        ? MangaAutoRead.pageStepDelay(_autoReadSpeed)
        : MangaAutoRead.webtoonCycle(_autoReadSpeed);
    _autoReadTimer = Timer.periodic(period, (_) => _autoReadTick());
  }

  /// [P4-3 E3] 定时器 tick：控制栏/面板/页操作底栏打开期间暂停（守卫见上）
  void _autoReadTick() {
    // [P4-3 W2-fix P2-1] 页操作底栏打开同样暂停（对齐参考版 LaunchedEffect
    // 依赖 activeSheet 的语义，原实现仅 _showControls 守卫）
    if (_showControls || _pageActionsOpen) return;
    if (MangaScrollModes.isPaged(_scrollMode)) {
      // 单页式：翻一页（边界自动切章，见 [_stepPage]；其内部已 unawaited）
      // [P4-3 W2-fix P2-6] 控制器尚未挂接（切章重建瞬间）本周期空转
      if (_pagedController?.hasClients != true) return;
      _stepPage(1);
      return;
    }
    // 条漫自动滚动（对齐参考版 MangaReaderScreen autoScrollWebtoon）：
    // 每周期滚 10000px，但距章末不足 10000px 时先滚完剩余距离
    //（参考版 animateScrollBy 的 consumed 被边界钳制，consumed<1 才切章，
    // 不会跳过章尾内容）
    // [P4-3 W2-fix P1-1③] 控制器无客户端时对齐 _preloadVisibleImages
    // 直接空转（原实现误当章末触发切章）
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final remaining = position.maxScrollExtent - position.pixels;
    if (remaining <= 0) {
      _scheduleAutoReadNextChapter();
      return;
    }
    // [P4-3 W2-fix ⑬] 在飞守卫：上一周期的滚动是「滚向章末」（目标已达
    // 章末）且尚未落定（future 未完成）时，本 tick 不重启 —— 由该滚动的
    // 完成回调（whenComplete）复检章末并当下调度切章（见下方）。低速
    //（周期长）下旧实现 tick 相位滞后、滚完剩余仍判「还有剩余」再爬一整
    // 周期，章尾停留 ≈ 3P（QA ⑬ 低速 ≥90s 同族）；中段滚动（目标 < 章末）
    // 不触发本守卫，逐周期续滚保持连续（对齐参考版 10000px/周期）。
    final inFlightTarget = _webtoonScrollTarget;
    if (_webtoonScrollInFlight &&
        inFlightTarget != null &&
        inFlightTarget >= position.maxScrollExtent - 1) {
      return;
    }
    // [P4-3 W2-fix P1-1①] 逐周期滚动部分距离（remaining 不足一周期时
    // 滚到章末），章末后延迟 500ms 切下一章（参考版 delay(500L)）
    final target =
        position.pixels +
        (remaining >= MangaAutoRead.webtoonScrollPx
            ? MangaAutoRead.webtoonScrollPx
            : remaining);
    final f = position.animateTo(
      target,
      duration: MangaAutoRead.webtoonCycle(_autoReadSpeed),
      curve: Curves.linear,
    );
    _webtoonScrollFuture = f;
    _webtoonScrollTarget = target;
    _webtoonScrollInFlight = true;
    // [P4-3 W2-fix ⑬] 滚动**完成当下**复检章末（1px 容差，对齐参考版
    // consumed<1f）：到章末即当下调度切章（500ms 后执行），不等下一个
    // 周期 tick
    f.whenComplete(() {
      // 仅当仍是当前在飞滚动才清标记（旧 future 被新滚动取消时其完成
      // 回调不应误清新滚动的在飞标记）
      if (identical(_webtoonScrollFuture, f)) {
        _webtoonScrollFuture = null;
        _webtoonScrollTarget = null;
        _webtoonScrollInFlight = false;
      }
      if (!mounted || !_autoRead || _showControls || _pageActionsOpen) {
        return;
      }
      if (!_scrollController.hasClients) return;
      final pos = _scrollController.position;
      if (pos.pixels >= pos.maxScrollExtent - 1) {
        _scheduleAutoReadNextChapter();
      }
    });
  }

  /// 条漫自动翻页到章末后延迟 500ms 切下一章
  ///
  /// [P4-3 W2-fix P1-1②] 延迟回调补 mounted / 自动翻页开关 / 控制栏与
  /// 页操作底栏 / 控制器挂载 / 位置复检守卫（原实现无守卫且定时器仍在
  /// tick，加载慢时回调直接切章会连跳多章）
  void _scheduleAutoReadNextChapter() {
    if (_autoReadChapterPending) {
      return;
    }
    _autoReadChapterPending = true;
    Future.delayed(const Duration(milliseconds: 500), () {
      _autoReadChapterPending = false;
      if (!mounted || !_autoRead || _showControls || _pageActionsOpen) {
        return;
      }
      if (!_scrollController.hasClients) return;
      final pos = _scrollController.position;
      // 复检：延迟期间用户手动滚动 / 控制器重建可能已离开章末
      if (pos.pixels < pos.maxScrollExtent - 1) {
        return;
      }
      unawaited(_nextChapter());
    });
  }

  /// [P4-3 E1] 应用翻页模式：
  /// - 单页式（1/2/3）→ 创建/同步 [PageController]（初始页 = 待恢复页或当前页）；
  /// - 条漫式（4/5）→ 释放单页控制器，以当前图片索引建立条漫原点。
  void _applyScrollMode() {
    _pageZoomed = false;
    if (MangaScrollModes.isPaged(_scrollMode)) {
      final n = _imageUrls.length;
      if (n == 0) return; // 图片未就绪：_loadChapterImages 完成后会再同步
      // 待恢复的页级进度优先（单页式定位由控制器 initialPage 完成，此处消费）
      final initial = _visiblePageIndex.clamp(0, n - 1);
      _visiblePageIndex = initial;
      _syncPagedController(initialLogical: initial);
    } else {
      _disposePagedController();
    }
  }

  /// [P4-3 E1] 模式/章节/初始页变化时重建 PageController；规格一致时保留当前页
  void _syncPagedController({required int initialLogical}) {
    if (_imageUrls.isEmpty) return;
    final n = _imageUrls.length;
    final axis = MangaScrollModes.axisOf(_scrollMode);
    final reversed = MangaScrollModes.isReversed(_scrollMode);
    final old = _pagedController;
    // 控制器与当前规格一致 → 保留用户当前页（不重置 initialPage）
    if (old != null &&
        _pagedAxis == axis &&
        _pagedReversed == reversed &&
        _pagedGen == _loadSeq) {
      return;
    }
    final display = MangaPagedView.displayIndexOf(
      logicalPage: initialLogical,
      pageCount: n,
      reversed: reversed,
    );
    final next = PageController(initialPage: display, viewportFraction: 1.0)
      ..addListener(_onPagedScroll);
    _pagedController = next;
    _pagedAxis = axis;
    _pagedReversed = reversed;
    _pagedGen = _loadSeq;
    if (mounted) setState(() {});
    if (old != null) {
      // 旧控制器仍附着于 PageView：须待 didUpdateWidget 解绑后再释放
      //（附着期同步 dispose 在 debug 断言）
      WidgetsBinding.instance.addPostFrameCallback((_) {
        old.dispose();
      });
    }
  }

  /// [P4-3 E1] 切回条漫式：释放单页式控制器（同样等解绑后释放）
  void _disposePagedController() {
    final old = _pagedController;
    _pagedController = null;
    if (old != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        old.dispose();
      });
    }
  }

  /// [P4-3 E1] 单页式页切换：更新可见页（精确页索引）+ 持久化进度 + 预载
  void _onPagedPageChanged(int displayIndex) {
    final n = _imageUrls.length;
    if (n == 0) return;
    final page = MangaPagedView.logicalPageOf(
      displayIndex: displayIndex,
      pageCount: n,
      reversed: MangaScrollModes.isReversed(_scrollMode),
    );
    if (page != _visiblePageIndex) {
      setState(() => _visiblePageIndex = page);
      // [P4-3 E1] 页级进度：单页式记录精确页索引（非比例估算），
      // 与 webtoon 的「可见页变化即持久化」事件驱动频率一致
      unawaited(_saveProgress());
    }
    _preloadVisibleImages();
  }

  /// [P4-3 E1] 单页式滚动：触发前后预载（±2 页）
  void _onPagedScroll() => _preloadVisibleImages();

  Future<void> _applyBrightness(int l) async {
    if (l <= 0) return;
    try {
      if (await SystemBrightness.isSupported()) {
        await SystemBrightness.setBrightness((l / 255.0).clamp(0.0, 1.0));
      }
    } catch (_) {}
  }

  void _openMangaConfig() {
    MangaConfigSheet.show(
      context,
      colorFilter: _colorFilter,
      footer: _footerConfig,
      enableEInk: _enableEInk,
      enableGray: _enableGray,
      eInkThreshold: _eInkThreshold,
      // [P4-3 E1] 翻页模式（对齐参考版阅读模式下拉）
      scrollMode: _scrollMode,
      // [P4-3 E3] 自动翻页（开关会话态 + 速度档 1..15 持久化）
      autoReadEnabled: _autoRead,
      autoReadSpeed: _autoReadSpeed,
      // [P4-3 E2] 分页适配类型（单页式映射 BoxFit；条漫恒 fitWidth）
      pageScaleType: _pageScaleType,
      onColorFilterChanged: (c) => unawaited(_settings.setColorFilter(c)),
      onFooterChanged: (c) => unawaited(_settings.setFooter(c)),
      onEnableEInkChanged: (v) => unawaited(_settings.setEInk(v)),
      onEnableGrayChanged: (v) => unawaited(_settings.setGray(v)),
      onEInkThresholdChanged: (v) => unawaited(_settings.setThreshold(v)),
      onScrollModeChanged: (m) => unawaited(_settings.setScrollMode(m)),
      onAutoReadChanged: (v) => _setAutoReadEnabled(v),
      onAutoReadSpeedChanged: (v) => unawaited(_settings.setAutoReadSpeed(v)),
      // [P4-3 E2] 分页适配类型变更持久化（对齐参考版 ViewModel L816）
      onPageScaleTypeChanged: (v) => unawaited(_settings.setPageScaleType(v)),
      // [P4-3 M3 修4] 条漫侧边留白（条漫专属滑杆，0..45% 持久化）
      sidePadding: _sidePadding,
      onSidePaddingChanged: (v) => unawaited(_settings.setSidePadding(v)),
      // [漫画设置作用域] 翻页模式 / 侧边留白的「跟随全局 / 本书」作用域控件
      // 接线：有当前书时才渲染（无书仅全局路径）；书级写入经 updateBook，
      // 清除覆盖 = 回调传 null（不写入默认值冒充清除）
      hasCurrentBook: _book != null,
      bookScrollMode: _bookScrollMode,
      globalScrollMode: _globalScrollMode,
      onBookScrollModeChanged: (v) => unawaited(_persistBookScrollMode(v)),
      bookSidePadding: _bookSidePadding,
      globalSidePadding: _globalSidePadding,
      onBookSidePaddingChanged: (v) => unawaited(_persistBookSidePadding(v)),
      // [P4-3 M4 批2] 行为开关组（8 布尔键 + 背景色；键名对齐原版
      // PreferKey，持久化经设置控制器）
      disableClickScroll: _disableClickScroll,
      disableMangaScale: _disableMangaScale,
      disableMangaPageAnim: _disableMangaPageAnim,
      hideMangaTitle: _hideMangaTitle,
      volumeKeyPage: _volumeKeyPage,
      reverseVolumeKeyPage: _reverseVolumeKeyPage,
      mangaLongClickSaveImage: _mangaLongClickSaveImage,
      disableMangaCrossFade: _disableMangaCrossFade,
      mangaBgColor: _mangaBgColor,
      onDisableClickScrollChanged: (v) =>
          unawaited(_settings.setToggle(MangaToggle.disableClickScroll, v)),
      onDisableMangaScaleChanged: (v) =>
          unawaited(_settings.setToggle(MangaToggle.disableMangaScale, v)),
      onDisableMangaPageAnimChanged: (v) =>
          unawaited(_settings.setToggle(MangaToggle.disableMangaPageAnim, v)),
      onHideMangaTitleChanged: (v) =>
          unawaited(_settings.setToggle(MangaToggle.hideMangaTitle, v)),
      onVolumeKeyPageChanged: (v) =>
          unawaited(_settings.setToggle(MangaToggle.volumeKeyPage, v)),
      onReverseVolumeKeyPageChanged: (v) =>
          unawaited(_settings.setToggle(MangaToggle.reverseVolumeKeyPage, v)),
      onMangaLongClickSaveImageChanged: (v) =>
          unawaited(_settings.setToggle(MangaToggle.longClickSaveImage, v)),
      onDisableMangaCrossFadeChanged: (v) =>
          unawaited(_settings.setToggle(MangaToggle.disableCrossFade, v)),
      onMangaBgColorChanged: (v) => unawaited(_settings.setBackground(v)),
      // [P4-3 M5] 九宫格点击区编辑器（对齐参考版 ClickActionsSettingsContent
      // L772-802：点击循环切换；单格索引回调，屏内即时生效）
      clickActions: _clickActions,
      onClickActionChanged: (index) =>
          unawaited(_settings.cycleClickAction(index)),
    );
  }

  /// [P4-3 M1] 刷新键：重载当前章节（对齐参考版 RefreshChapter，
  /// MangaReaderViewModel L244-253：setMenuVisible(false) +
  /// invalidateCurrentChapter() + RetryChapter）：先收起控制栏，再走
  /// [_loadChapterImages] 重取路径（清空内容缓存 → 在线 fetchChapterContent
  /// 重抓 / 本地 getChapterContent 重读）。
  void _refreshChapter() {
    if (_showControls) _toggleControls();
    unawaited(_loadChapterImages());
  }

  /// [P4-3 M1] 目录键：弹目录 bottom sheet（对齐参考版 OpenCatalog =
  /// ReaderBookSheetRoute(initialTab=Toc)，取证见 manga_catalog_sheet.dart）
  void _openCatalog() {
    MangaCatalogSheet.show(
      context,
      chapters: _chapters,
      currentIndex: _currentChapterIndex,
      onSelected: (index) => unawaited(_goToChapter(index)),
    );
  }

  /// [P4-3 M3 修2] 顶栏换源键：复用既有换源底部弹层（AppRoutes.changeSource，
  /// 详情页 _showChangeSourceDialog / 听书页 _openChangeSource 同款先例——
  /// 换源页为半透明 sheet 路由，压在本阅读页上方，真实换源功能）：
  /// 传当前书籍打开换源 sheet；换源成功路由回传新 bookUrl（String），
  /// 切换 [_activeBookUrl] 后整书重载（章节/图片/进度全部跟新源）。
  /// 未换源（pop 无结果）保持当前源不变。书籍未加载完时 no-op 守卫。
  void _openChangeSource() {
    final book = _book;
    if (book == null) return;
    unawaited(
      GoRouter.of(context)
          .pushAppRoute(AppRoutes.changeSource, extra: book)
          .then((dynamic result) {
            final newBookUrl = result is String ? result : null;
            if (newBookUrl == null || newBookUrl.isEmpty || !mounted) return;
            unawaited(_reader.open(bookUrl: newBookUrl));
          }),
    );
  }

  /// [P4-3 M1] 底栏页进度滑条 seek：跳到目标逻辑页（对齐参考版
  /// SeekToPage intent；no-op 守卫：目标 = 当前页 / 已在目标像素时不触发
  /// 进度写入，保证 progressCalls 不因无效拖拽增长）
  void _seekToPage(int page) {
    final n = _imageUrls.length;
    if (n == 0) return;
    final target = page.clamp(0, n - 1);
    if (target == _visiblePageIndex) return;
    if (MangaScrollModes.isPaged(_scrollMode)) {
      // 单页式：PageController 动画翻到目标显示索引（逻辑页 → 显示索引
      // 经 MangaPagedView.displayIndexOf 换算，R2L 时控制器方向取反，
      // 同 _stepPage 先例）
      final controller = _pagedController;
      if (controller == null || !controller.hasClients) return;
      final display = MangaPagedView.displayIndexOf(
        logicalPage: target,
        pageCount: n,
        reversed: MangaScrollModes.isReversed(_scrollMode),
      );
      final current = (controller.page ?? 0).round();
      if (current == display) return; // 已在目标页（动画未落定）
      // [P4-3 M4 批2] 禁用翻页动画：jumpToPage 替代 animateToPage
      if (_disableMangaPageAnim) {
        controller.jumpToPage(display);
      } else {
        controller.animateToPage(
          display,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
      return;
    }
    _webtoonAnchors.jumpToPage(target);
  }

  /// 图片渲染滤镜：灰度用 ColorFilter；电子纸走真像素二值化（见图片组件）
  ColorFilter? get _imageColorFilter {
    if (_enableEInk) return null;
    if (_enableGray) {
      return const ColorFilter.matrix(kMangaGrayscaleMatrix);
    }
    if (_colorFilter.isIdentity) return null;
    return ColorFilter.matrix(_colorFilter.toColorMatrix());
  }

  /// 会话数据变化只投影到视口，滚动与动画仍由页面管理。
  void _onReaderChanged() {
    if (!mounted) return;
    final previous = _observedSession;
    final next = _reader.state;
    _observedSession = next;
    if (next.navigationId != previous.navigationId) {
      _pageZoomed = false;
      _visiblePageIndex = next.initialPage;
      _firstVisiblePageIndex = next.initialPage;
      _lastVisiblePageIndex = next.initialPage;
    }
    if (next.book != previous.book) _onSettingsChanged();
    setState(() {
      if (next.loading) _failedIndices.clear();
    });
    if (previous.loading &&
        !next.loading &&
        next.error == null &&
        next.imageUrls.isNotEmpty) {
      if (MangaScrollModes.isPaged(_scrollMode)) {
        final initial = _visiblePageIndex.clamp(0, _imageUrls.length - 1);
        _visiblePageIndex = initial;
        _syncPagedController(initialLogical: initial);
      }
      _preloadVisibleImages();
    }
  }

  Future<void> _loadBook() => _reader.open();

  Future<void> _loadChapterImages() => _reader.refreshChapter();

  /// 页码、持久化和预载共用已实际布局的可见图片区间。— Codex + UI
  void _onVisiblePagesChanged(int first, int last) {
    // 参考版当前章使用视口底部可见图片作为阅读页，顶部索引仅用于预载。
    if (_visiblePageIndex != last) {
      setState(() => _visiblePageIndex = last);
      unawaited(_saveProgress());
    }
    _firstVisiblePageIndex = first;
    _lastVisiblePageIndex = last;
    _preloadVisibleImages();
  }

  void _preloadVisibleImages() {
    if (!mounted || _imageUrls.isEmpty) return;
    _preloadIndicesInRange(
      (MangaScrollModes.isPaged(_scrollMode)
              ? _visiblePageIndex
              : _firstVisiblePageIndex) -
          _preloadRange,
      (MangaScrollModes.isPaged(_scrollMode)
              ? _visiblePageIndex
              : _lastVisiblePageIndex) +
          _preloadRange,
    );
  }

  void _preloadIndicesInRange(int start, int end) {
    if (!mounted) return;
    _reader.preloadRange(
      start,
      end,
      precacheNetwork: (url) =>
          precacheImage(CachedNetworkImageProvider(url), context),
    );
  }

  Future<void> _goToChapter(int index) =>
      _reader.goToChapter(index, currentPage: _visiblePageIndex);

  /// 切换到下一章
  Future<void> _nextChapter() async {
    if (_currentChapterIndex < _chapters.length - 1) {
      await _goToChapter(_currentChapterIndex + 1);
    }
  }

  /// 切换到上一章
  Future<void> _prevChapter() async {
    if (_currentChapterIndex > 0) {
      await _goToChapter(_currentChapterIndex - 1);
    }
  }

  Future<void> _saveProgress() => _reader.saveProgress(_visiblePageIndex);

  /// 切换控制栏显示/隐藏
  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    // [P4-3 M1] 菜单滑入/滑出动画（隐藏时动画落定后子树移除，
    // 见 build 的 AnimatedBuilder）
    if (AppMotion.reduced(context)) {
      _menuCtrl.value = _showControls ? 1 : 0;
    } else if (_showControls) {
      _menuCtrl.forward();
    } else {
      _menuCtrl.reverse();
    }
    // [P4-3 E3] 控制栏收起 = 自动翻页恢复（对齐参考版 LaunchedEffect 依赖
    // menuVisible/activeSheet 变化重建：从新周期开始计时）
    if (!_showControls) _restartAutoReadTimer();
  }

  // ---------------------------------------------------------------------------
  // [P4-3 E5] 九区点击 + 长按菜单
  //
  // 取证（参考版 legado-with-MD3）：
  // - MangaReaderInteraction.kt L15-41：九区索引（row*3+col）/动作解析/循环；
  // - MangaReaderScreen.kt L1945-1969 performMangaClickAction：
  //   -1 无动作 / 0 菜单 / 1 下一页 / 2 上一页 / 3 下一章 / 4 上一章；
  //   L705-736 条漫点击 = 滚一视口（不足一视口 → 切章）；
  //   L930-1000 单页点击 = 翻页 intent（R2L 阅读「下一页」= 显示索引减小）。
  // ---------------------------------------------------------------------------

  /// [P4-3 E5] 九区点击入口：tap-up 位置 → 区域 → 动作
  ///
  /// 按下/抬起位移超过 8px 视为滑动/缩放意图，不触发点击（对齐参考版
  /// tap 判定语义；视口级 GestureDetector 只收「点」不收「滑」）。
  void _onTapInRegion(Offset up, Size viewport) {
    final down = _tapDownPosition;
    _tapDownPosition = null;
    if (down == null) return;
    if ((up - down).distance > 8) return;
    final action = MangaClickActions.actionAt(
      _clickActions,
      up.dx,
      up.dy,
      viewport.width,
      viewport.height,
    );
    _executeClickAction(action);
  }

  /// [P4-3 E5] 执行点击动作（动作语义见 [_executeClickAction] 注释）
  void _executeClickAction(int action) {
    // [P4-3 M4 批2] 禁用点击翻页：翻页类动作 1/2（下一页/上一页）失效，
    // 0 菜单 / 3 下一章 / 4 上一章保留（对齐参考版 MangaReaderScreen
    // L1953/L714 disableClickScroll 守卫）
    if ((_disableClickScroll || _pageZoomed) &&
        (action == MangaClickActions.next ||
            action == MangaClickActions.prev)) {
      return;
    }
    switch (action) {
      case MangaClickActions.none:
        break; // -1：无动作（对齐参考版 none）
      case MangaClickActions.menu:
        _toggleControls(); // 0：控制栏显隐（对齐参考版 ToggleMenu）
      case MangaClickActions.next:
        _stepPage(1);
      case MangaClickActions.prev:
        _stepPage(-1);
      case MangaClickActions.nextChapter:
        unawaited(_nextChapter());
      case MangaClickActions.prevChapter:
        unawaited(_prevChapter());
    }
  }

  /// [P4-3 E5] 单步翻页 / 条漫滚一视口
  ///
  /// [direction] 1 = 阅读方向下一页，-1 = 上一页。
  /// - 单页式：PageController 动画翻页；边界按**逻辑页**判定
  ///   （对齐参考版 requestPageStep 的 nextPageItemIndex null →
  ///   openRelativeChapter）；R2L 时阅读「下一页」= 显示索引减小
  ///   （控制器方向取反，仅用于动画目标换算）；
  /// - 条漫：纵向滚动一视口，目标被章边界钳制（对齐参考版
  ///   performWebtoonTap 的 animateScrollBy 部分消费）；只有真正
  ///   已在章边界（无可滚距离）才切章（consumed < 1 语义）。
  void _stepPage(int direction) {
    if (MangaScrollModes.isPaged(_scrollMode)) {
      final controller = _pagedController;
      final n = _imageUrls.length;
      // [P4-3 W2-fix P2-6] 控制器尚未挂接（切章重建瞬间）空转
      if (controller == null || !controller.hasClients || n == 0) return;
      final reversed = MangaScrollModes.isReversed(_scrollMode);
      // [P4-3 W2-fix P0-1] 边界按逻辑页判定（_visiblePageIndex 是逻辑页：
      // 0 = 阅读首页 .. n-1 = 末页），对齐参考版 requestPageStep
      // 「nextPageItemIndex 返回 null → openRelativeChapter」：
      // R2L（reversed 布局：导航页占显示索引 0、真实页占 1..n）下原
      // display 换算判定全错——第 2 页点上一页被误判边界直接切上一章、
      // 第 1 页点上一页越界永不切章、末页点下一页落到导航页。
      final logical = _visiblePageIndex;
      final atBoundary = direction > 0 ? logical == n - 1 : logical == 0;
      if (atBoundary) {
        unawaited(direction > 0 ? _nextChapter() : _prevChapter());
        return;
      }
      final display = MangaPagedView.displayIndexOf(
        logicalPage: logical,
        pageCount: n,
        reversed: reversed,
      );
      // R2L：控制器翻页方向与阅读方向相反
      final controllerDirection = reversed ? -direction : direction;
      // [P4-3 M4 批2] 禁用翻页动画：jumpToPage 替代 animateToPage
      //（目标计算不变；自动翻页定时器条漫路径 animateTo 保留）
      if (_disableMangaPageAnim) {
        controller.jumpToPage(display + controllerDirection);
      } else {
        controller.animateToPage(
          display + controllerDirection,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
      return;
    }
    // 条漫：纵向滚动一视口（条漫恒为纵向 ListView）
    // [P4-3 W2-fix P1-2] 对齐参考版 performWebtoonTap（L705-732）：
    // 先滚一视口（被章边界钳制、部分消费），只有真正已在章边界
    // （consumed < 1，即无可滚距离）才切章；原实现距章尾不足一视口时
    // 直接跳章、跳过剩余内容。
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (direction > 0) {
      if (position.pixels >= position.maxScrollExtent) {
        unawaited(_nextChapter());
        return;
      }
      var target = position.pixels + position.viewportDimension;
      if (target > position.maxScrollExtent) {
        target = position.maxScrollExtent; // 滚完剩余距离（部分消费）
      }
      // [P4-3 M4 批2] 禁用翻页动画：jumpTo 替代 animateTo（目标不变）
      if (_disableMangaPageAnim) {
        position.jumpTo(target);
      } else {
        position.animateTo(
          target,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
      return;
    }
    if (position.pixels <= position.minScrollExtent) {
      unawaited(_prevChapter());
      return;
    }
    var target = position.pixels - position.viewportDimension;
    if (target < position.minScrollExtent) {
      target = position.minScrollExtent; // 滚完剩余距离（部分消费）
    }
    if (_disableMangaPageAnim) {
      position.jumpTo(target);
    } else {
      position.animateTo(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // [P4-3 E5] 长按页操作菜单（保存 / 分享 / 复制）
  //
  // 取证：参考版 MangaReaderViewModel L300-340（LongPressPage →
  // PageActions 底栏）、MangaReaderSheets L179-252（底栏三项单页动作）、
  // 原版 ReadMangaActivity L242-276（长按存图：用户先选目录再写入）。
  // 图片字节解析：内存缓存 → 磁盘缓存（getImageCache）→ FFI 解码回退，
  // 不重新下载（见 manga_page_image_resolver.dart）。
  // ---------------------------------------------------------------------------

  /// 显示长按页操作菜单（对齐参考版单页 onLongClick L1082 / 条漫长按 L761-771）
  void _showPageActions(int index) {
    if (index < 0 || index >= _imageUrls.length) return;
    // [P4-3 W2-fix P2-1] 底栏打开期间自动翻页暂停（对齐参考版
    // LaunchedEffect 依赖 activeSheet；关闭时复位）
    _pageActionsOpen = true;
    // [cbz 批 D] 本地 cbz 页伪 URL（cbz://<条目名>）不是可消费链接 →
    // 隐藏「复制链接」项；保存/分享由图片操作服务读取CBZ条目字节。
    final isCbz = _imageUrls[index].startsWith('cbz://');
    showMangaPageActionsSheet(
      context,
      onSave: () => _savePageImage(index),
      onShare: () => _sharePageImage(index),
      onCopy: isCbz ? null : () => _copyPageImage(index),
    ).whenComplete(() {
      if (mounted) _pageActionsOpen = false;
    });
  }

  ComicPageImage _pageImage(int index) => ComicPageImage(
    bookUrl: _activeBookUrl,
    url: _imageUrls[index],
    book: _book,
    source: _bookSource,
  );

  Future<void> _savePageImage(int index) async {
    final result = await _imageActions.save(_pageImage(index));
    _showPageActionSnackBar(result);
  }

  Future<void> _sharePageImage(int index) async {
    final result = await _imageActions.share(_pageImage(index));
    if (result != null) _showPageActionSnackBar(result);
  }

  Future<void> _copyPageImage(int index) async {
    _showPageActionSnackBar(await _imageActions.copy(_pageImage(index)));
  }

  /// 页操作结果提示（项目先例：ScaffoldMessenger.showSnackBar）
  void _showPageActionSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
  }

  /// 重试加载失败的图片
  void _retryImage(int index) {
    setState(() {
      _failedIndices.remove(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      // 退出时保存进度
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          unawaited(_saveProgress());
        }
      },
      child: Scaffold(
        // [P4-3 M4 批2] 阅读背景色（ARGB 整型持久化；默认黑 0xFF000000
        // = 原硬编码 Colors.black，默认行为零变化）
        backgroundColor: Color(_mangaBgColor),
        // [P4-3 E5] 九区点击：视口级 GestureDetector 承担点击导航
        //（对齐参考版「导航属于视口而非单个变换后的条漫项」）；
        // 子项的长按手势与按钮仍按竞技场规则优先命中
        body: LayoutBuilder(
          builder: (context, constraints) {
            final viewport = Size(constraints.maxWidth, constraints.maxHeight);
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) => _tapDownPosition = details.localPosition,
              onTapUp: (details) =>
                  _onTapInRegion(details.localPosition, viewport),
              child: Stack(
                children: [
                  // 主内容区域
                  _buildContent(),
                  // 漫画页脚信息条（对标原版 ReaderInfoBar）
                  if (!_footerConfig.hideFooter) _buildMangaFooter(),
                  // [P4-3 M1] 菜单顶栏（悬浮胶囊，透明底 + 滑入动画；
                  // 隐藏动画落定后 AnimatedBuilder 返回 shrink 移除子树）
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: _buildAnimatedMenu(_topBarPos, _buildTopBar),
                  ),
                  // [P4-3 M1] 菜单底栏（悬浮圆角面板，两行结构）
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: _buildAnimatedMenu(_bottomBarPos, _buildBottomBar),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// 构建主内容区域
  Widget _buildContent() {
    if (_loading) {
      return const LoadingIndicator(message: '加载漫画中...');
    }

    if (_error != null) {
      return ErrorView(
        message: _error!,
        // [P4-3 E4] 章级错误（章节正文获取失败 / 0 图校验失败）重试只重载
        // 当前章（对齐参考版 RetryChapter L308-318）；书级错误（书籍信息/
        // 目录获取失败）仍走整书重载
        onRetry: _errorChapterLevel ? _loadChapterImages : _loadBook,
      );
    }

    // [P4-3 E4] 0 图分支：非卷章 0 图已在上方进入错误态（正文没有图片），
    // 到达这里的只有卷章（isVolume）0 图 = 合法分隔页（对齐原版
    // ReadManga L635-636 卷章渲染 ReaderLoading(chapter.index, -1,
    // chapter.title, true) 分隔页；参考版 L452-460 ChapterEdge "volume:..."
    // message=chapterTitle）：显示章节标题 + 上下章导航（非「暂无图片」、
    // 非错误态）
    if (_imageUrls.isEmpty) {
      final chapter = _chapters[_currentChapterIndex];
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // [P4-3 M4 批2] 隐藏漫画列表标题：0 图卷章分隔页标题隐藏
            //（我方无独立章节标题页，hideMangaTitle 映射到此 + 导航区；
            // 上下章按钮保留）
            if (!_hideMangaTitle) ...[
              Text(
                chapter.title.isNotEmpty ? chapter.title : '暂无图片',
                style: const TextStyle(color: Colors.white70, fontSize: 18),
              ),
              const SizedBox(height: 24),
            ],
            // 章节导航按钮（卷章分隔页仍需跳转上下章）
            if (_currentChapterIndex > 0)
              TextButton(
                onPressed: _prevChapter,
                child: const Text(
                  '上一章',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            if (_currentChapterIndex < _chapters.length - 1)
              TextButton(
                onPressed: _nextChapter,
                child: const Text(
                  '下一章',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
          ],
        ),
      );
    }

    // [P4-3 E1] 模式分发：单页式（1/2/3）→ 分页器；条漫式（4/5）→ 连续滚动
    return MangaScrollModes.isPaged(_scrollMode)
        ? _buildPagedContent()
        : _buildImageList();
  }

  /// [P4-3 E1] 构建单页式分页器（L2R/R2L 横向、T2B 纵向；R2L 首页在右）
  Widget _buildPagedContent() {
    if (_pagedController == null) {
      // 防御：控制器未及创建（模式晚于图片生效且未同步）→
      // 本帧回退条漫路径，postFrame 创建控制器后切换
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && MangaScrollModes.isPaged(_scrollMode)) {
          _syncPagedController(initialLogical: _visiblePageIndex);
        }
      });
      return _buildImageList();
    }
    return MangaPagedView(
      // [P4-3 W2-fix P0-2] 代数 key：切章 _loadSeq 递增（见 _goToChapter）
      // 时强制重建 PageView 子树（新 State / 新滚动位置），使新控制器的
      // initialPage（章首 0 页）真正生效。无 key 时，加载间隙若未跨帧
      // （图片已缓存 / 测试桩立即返回），PageView 不卸树，旧滚动位置
      // 被保留、新控制器 initialPage 失效 → 新章按旧像素偏移停靠
      // （durChapterPos=2 恢复进入后切章仍停在第 3 页，页脚却显示 1/3）。
      // 参考版：切章原子置 currentItemIndex = 0 且 navigationId 换代
      // （MangaReaderViewModel.kt L1112/L1118），上下章恒 pageIndex = 0
      // （L1124）；分页器按代归位（MangaReaderScreen.kt L859-862
      // rememberPagerState(initialPage)，L875-886 按 currentItemIndex /
      // navigationId 的 LaunchedEffect → scrollToPage(target)）。
      key: ValueKey('mangaPaged-$_loadSeq'),
      controller: _pagedController!,
      disableScale: _disableMangaScale,
      onZoomChanged: (value) => _pageZoomed = value,
      pageCount: _imageUrls.length,
      axis: MangaScrollModes.axisOf(_scrollMode),
      reversed: MangaScrollModes.isReversed(_scrollMode),
      onDisplayIndexChanged: _onPagedPageChanged,
      pageBuilder: (context, logicalPage) => _buildImageItem(logicalPage),
      navBuilder: (context) => _buildChapterNavigation(),
    );
  }

  /// 条漫图片索引定位与可见项统计由视口统一管理。
  Widget _buildImageList() => ComicWebtoonView(
    key: ValueKey(('webtoon', _loadSeq)),
    anchors: _webtoonAnchors,
    initialPage: _visiblePageIndex,
    onVisibleRangeChanged: _onVisiblePagesChanged,
    controller: _scrollController,
    pageCount: _imageUrls.length,
    pageBuilder: (_, index) => _buildImageItem(index),
    navigationBuilder: (_) => _buildChapterNavigation(),
    disableScale: _disableMangaScale,
    withGap: _scrollMode == MangaScrollModes.webtoonWithGap,
    sidePadding: MangaScrollModes.isWebtoon(_scrollMode) ? _sidePadding : 0,
  );

  Widget _buildImageItem(int index) => ComicImageItem(
    url: _imageUrls[index],
    book: _book,
    source: _bookSource,
    bookUrl: _activeBookUrl,
    images: ref.read(bookImageRepositoryProvider),
    localBooks: ref.read(localBookServiceProvider),
    network: ref.read(networkServiceProvider),
    failed: _failedIndices.contains(index),
    headers: _imageHeaders,
    fit: _imageFit,
    smartFit:
        MangaScrollModes.isPaged(_scrollMode) &&
        _pageScaleType == MangaPageScaleType.smartFit,
    colorFilter: _imageColorFilter,
    enableEInk: _enableEInk,
    eInkThreshold: _eInkThreshold,
    disableCrossFade: _disableMangaCrossFade,
    onError: () => WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_failedIndices.contains(index)) {
        setState(() => _failedIndices.add(index));
      }
    }),
    onRetry: () => _retryImage(index),
    onLongPress: () {
      if (_mangaLongClickSaveImage) {
        unawaited(_savePageImage(index));
      } else {
        _showPageActions(index);
      }
    },
  );

  /// 章节导航区域（显示在图片列表底部）
  Widget _buildChapterNavigation() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          // 当前章节标题
          // [P4-3 M4 批2] 隐藏漫画列表标题：导航区标题隐藏（按钮保留）
          if (_currentChapterIndex < _chapters.length && !_hideMangaTitle)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                _chapters[_currentChapterIndex].title,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
          // 导航按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 上一章
              if (_currentChapterIndex > 0)
                OutlinedButton.icon(
                  onPressed: _prevChapter,
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('上一章'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                  ),
                ),
              const SizedBox(width: 24),
              // 下一章
              if (_currentChapterIndex < _chapters.length - 1)
                OutlinedButton.icon(
                  onPressed: _nextChapter,
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: const Text('下一章'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// [P4-3 M1] 菜单动画包裹：顶栏自上 / 底栏自下滑入 + 淡入；
  /// 隐藏时动画反向播放，**动画落定后**（isAnimating=false 帧）返回
  /// SizedBox.shrink 移除菜单子树——保证隐藏态测试树中无菜单文本
  /// （find.text(书名) findsNothing）且动画期间 IgnorePointer 不响应。
  Widget _buildAnimatedMenu(Animation<Offset> slide, WidgetBuilder buildBar) {
    return AnimatedBuilder(
      animation: _menuCtrl,
      builder: (context, _) {
        // 隐藏且动画已落定 = 彻底移除（不再占树）
        if (!_showControls && !_menuCtrl.isAnimating) {
          return const SizedBox.shrink();
        }
        return IgnorePointer(
          // 滑出动画期间不响应点击（对齐参考版菜单可见才可操作）
          ignoring: !_showControls,
          child: SlideTransition(
            position: slide,
            child: FadeTransition(
              opacity: _menuOpacity,
              child: buildBar(context),
            ),
          ),
        );
      },
    );
  }

  /// [P4-3 M2] 源名取证（按用户截图：顶栏次行右端显示源名）
  ///
  /// 字段取证：`Book.origin` = 书源 URL（不适合展示）；
  /// `Book.originName` = DB 源显示名（默认空串）。优先取已解析的
  /// [_bookSource]（BookSource.bookSourceName，同 reader_menu_actions.part.dart
  /// L728-729 先例 `(source?.bookSourceName ?? book.originName).trim()`）。
  /// 空值 / URL 形态（http 前缀）判为取不到 → 返回 null，
  /// 顶栏次行仅显示章节名（截图基准：取不到不显，不放假值）。
  String? get _sourceName {
    final name = (_bookSource?.bookSourceName ?? _book?.originName ?? '')
        .trim();
    if (name.isEmpty) return null;
    if (name.startsWith('http://') || name.startsWith('https://')) {
      return null;
    }
    return name;
  }

  /// [P4-3 M2] 「更多」键：打开页操作底栏（复用既有页操作菜单
  /// 保存/分享/复制，作用于当前可见页）
  void _openPageActions() {
    _showPageActions(_visiblePageIndex);
  }

  /// [P4-3 M2/M3] 构建顶部控制栏（实心 AppBar 式，按用户截图重构：
  /// surfaceContainer 实心背景（覆盖状态栏区）+ Row1 返回/换源/刷新/更多 +
  /// Row2 书名大字 + 章节名 + 源名；「更多」= 打开页操作底栏；
  /// [P4-3 M3 修2] 换源键 = 复用既有换源底部弹层（_openChangeSource）
  Widget _buildTopBar(BuildContext context) {
    final chapterName = _currentChapterIndex < _chapters.length
        ? _chapters[_currentChapterIndex].title
        : null;
    return MangaMenuTopBar(
      bookName: _book?.name ?? '漫画阅读',
      chapterName: chapterName,
      sourceName: _sourceName,
      onBack: () => Navigator.of(context).pop(),
      onChangeSource: _openChangeSource,
      onRefresh: _refreshChapter,
      onMore: _openPageActions,
    );
  }

  /// [P4-3 M1] 漫画页脚信息条（对齐参考版 MangaFooter L114-154：
  /// 白字 + 黑字阴影 78% alpha offset 1.5/1.5 blur 3，替代旧暗色底块；
  /// 控制栏显示时上抬避让悬浮底栏）
  Widget _buildMangaFooter() {
    final chapterName = _currentChapterIndex < _chapters.length
        ? _chapters[_currentChapterIndex].title
        : '';
    final label = _footerConfig.buildLabel(
      chapterName: chapterName,
      chapterIndex: _currentChapterIndex,
      chapterSize: _chapters.length,
      pageIndex: _visiblePageIndex.clamp(
        0,
        _imageUrls.isEmpty ? 0 : _imageUrls.length - 1,
      ),
      imageCount: _imageUrls.length,
    );
    if (label.isEmpty) return const SizedBox.shrink();
    final align =
        _footerConfig.footerOrientation == MangaFooterConfig.alignCenter
        ? Alignment.center
        : Alignment.centerLeft;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    // [P4-3 M2] 控制栏可见时上抬避让两段底栏（进度行 56 + 间隙 8 +
    // 贴底白条 56 + 间隙 8 = 128；段间尺寸常量见 manga_menu.dart）
    final lift = _showControls
        ? kMangaProgressRowHeight +
              kMangaBottomSegmentGap +
              kMangaBottomBarHeight +
              kMangaBottomSegmentGap
        : 0;
    return Positioned(
      left: 16,
      right: 16,
      bottom: bottomInset + 12 + lift,
      child: IgnorePointer(
        child: Align(
          alignment: align,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              // 参考版 MangaFooterTextShadow：黑 78% / offset(1.5,1.5) /
              // blur 3（白字直接浮于漫画内容上，无暗色底块）
              shadows: [
                Shadow(
                  color: Color.fromRGBO(0, 0, 0, 0.78),
                  offset: Offset(1.5, 1.5),
                  blurRadius: 3,
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  /// [P4-3 M2] 构建底部控制栏（两段分离：进度行悬浮 + 贴底白条三键，
  /// 按用户截图重构；参数与语义不变，见 manga_menu.dart 组件文档）
  Widget _buildBottomBar(BuildContext context) {
    final pageCount = _imageUrls.length;
    return MangaMenuBottomBar(
      // 上一章/下一章（边界由 _prevChapter/_nextChapter 内部守卫）
      onPrevChapter: () => unawaited(_prevChapter()),
      onNextChapter: () => unawaited(_nextChapter()),
      // 页进度滑条（对齐参考版 ReadMenuSlider：value = 0 基页索引、
      // 范围 0..(pageCount-1).coerceAtLeast(1)、steps = (pageCount-2)）
      pageValue: (pageCount > 0 ? _visiblePageIndex.clamp(0, pageCount - 1) : 0)
          .toDouble(),
      pageMax: (pageCount - 1).clamp(1, 999999).toDouble(),
      divisions: pageCount > 1 ? pageCount - 1 : null,
      pageEnabled: pageCount > 1,
      readingPageDescription: pageCount > 0
          ? '页数 ${_visiblePageIndex + 1}/$pageCount'
          : '',
      onSeekPage: _seekToPage,
      // 目录键（弹目录 sheet，取证见 manga_catalog_sheet.dart）
      onOpenCatalog: _openCatalog,
      // 自动键（点击 = ToggleAutoRead；长按 = 自动翻页设置，
      // 参考版 OpenSettings(AUTO_READ)；本方设置面板含自动翻页区块）
      autoReadEnabled: _autoRead,
      onToggleAutoRead: () => _setAutoReadEnabled(!_autoRead),
      onOpenAutoSettings: _openMangaConfig,
      // 翻页设置键（参考版 OpenSettings(READER) → 漫画设置面板）
      onOpenPageSettings: _openMangaConfig,
    );
  }
}
