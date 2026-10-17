import 'views/comic_webtoon_view.dart';
import '../application/comic_preload_service.dart';
import 'views/comic_image_item.dart';
import '../../../data/services/comic_image_decode_cache.dart';
import '../../bookshelf/bookshelf_repositories.dart';
import '../../../providers/reading_provider.dart';
import '../../book_sources/book_source_repository_provider.dart';
import '../../../providers/book_content_provider.dart';
import '../../../providers/config_settings_provider.dart';
import '../../../domain/models/manga_settings.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io' show File;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../providers/network_provider.dart';

import '../../../models/models.dart';
import '../../../routes.dart';
import '../../../providers/media_provider.dart';
import '../../../services/platform_bridge_service.dart';
import '../../../services/system_brightness.dart';
import '../../../utils/comic_image_utils.dart';
import '../../../utils/error_message.dart';
import '../../../widgets/loading_indicator.dart';
import '../../../widgets/error_view.dart';
import 'overlays/manga_config_sheet.dart';
import '../../../models/manga_auto_read.dart';
import 'overlays/manga_catalog_sheet.dart';
import '../../../models/manga_click_actions.dart';
import 'overlays/manga_menu.dart';
import 'views/manga_paged_view.dart';
import 'overlays/manga_page_actions_sheet.dart';
import '../application/manga_page_image_resolver.dart';
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
  final ScrollController _scrollController = ScrollController();

  /// 当前书籍（用于加载章节和图片）
  Book? _book;

  /// [P4-3 M3 修2] 活跃 bookUrl（初始 = [ReaderComicScreen.bookUrl]；
  /// 顶栏换源键成功换源后切到新源 URL 并整书重载——widget 参数不可变，
  /// 用屏内状态承载当前源，屏内所有按 bookUrl 的取数/缓存/进度均走此值）
  late String _activeBookUrl;

  /// 章节列表
  List<BookChapter> _chapters = [];

  /// 当前章节索引
  int _currentChapterIndex = 0;

  /// 当前章节的图片 URL 列表
  List<String> _imageUrls = [];

  /// 加载状态
  bool _loading = true;

  /// 错误信息
  String? _error;

  /// 是否显示控制栏（顶部返回 + 底部进度条）
  bool _showControls = false;

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
  late final Animation<double> _menuOpacity;

  /// 图片窗口去重与相邻章预载由同一会话服务管理。
  late final ComicPreloadService _preloader;

  /// 图片加载失败的索引集合（用于显示重试按钮）
  final Set<int> _failedIndices = {};

  /// 书源防盗链 header（Referer/UA 等，对齐原版 glide getGlideUrl 带书源 headerMap）
  /// [UI-fix 2026-08-10 | Reasonix] 漫画 CDN 常校验 Referer，无 header 时 403
  Map<String, String> _imageHeaders = const {};

  /// 当前书源（含 imageDecode 规则；解码走 FFI fetchImageWithDecode）
  /// [UI-fix v2.0.19 | Reasonix] 对齐原版 ImageUtils.decodeImageStream：
  /// 漫画/图片站图片 bytes 经书源 imageDecode JS 解密后才可显示
  BookSource? _bookSource;

  /// 预加载缓存（前后各 2 页）
  static const int _preloadRange = 2;

  /// 漫画专用配置（对齐原版 PreferKey manga*）— GapAudit P0-3
  MangaColorFilterConfig _colorFilter = MangaColorFilterConfig();
  MangaFooterConfig _footerConfig = MangaFooterConfig();
  bool _enableEInk = false;
  bool _enableGray = false;
  int _eInkThreshold = 150;

  /// 页脚用「当前可见页」近似索引（滚动估算）
  int _visiblePageIndex = 0;

  /// [P4-1 C1] 页级进度恢复目标页（取自 book.durChapterPos；null = 章首开始）
  ///
  /// 非 null 时表示「待应用 / 锚定中」：图片解码期间内容高度不稳定
  /// （占位 0.6 屏 → 未解码 0 → 实际高度），每次内容度量变化（
  /// [ScrollMetricsNotification]）都会把视图重新锚定到记录页，直到
  /// 用户手动滚动（[_onScroll] 消费）或切章（[_goToChapter] 清零）。
  /// 对齐原版 ReadManga.upData → scrollToPositionWithOffset 定位语义。
  int? _restorePageIndex;

  /// [P4-1 C1] 标记「本次滚动来自恢复跳转」（jumpTo 触发的 [_onScroll]
  /// 不视为用户操作，不终止页级恢复锚定）
  bool _isRestoreJump = false;

  /// [P4-1 C3] 相邻章预载代数（换书/取消守卫，对齐 C1b 代数守卫先例）
  ///
  /// [P4-3 E4] 会话加载 token 映射登记（只登记映射、不重复实现）：
  /// 参考版 `MangaLoadToken(sessionId, revision, bookUrl, chapterIndex)`
  /// （MangaReaderSessionModels.kt L42-61）+ `MangaSessionState.accepts(token)`
  /// （L76-79：sessionId/revision/bookUrl 失配即丢弃在飞结果；
  /// DefaultMangaReaderSession chapterLoaded L276-296 同语义）——本字段是其
  /// 简化等价物：屏幕实例即唯一会话（实例 bookUrl 固定）≡ sessionId+bookUrl，
  /// 换书（_loadBook）/切章（_goToChapter）递增代数 ≡ revision 换代；
  /// 在飞相邻章预载经代数失配中止（_preloadAdjacentChapters `seq != _loadSeq`
  /// 守卫），陈旧的单页式子树经代数 `ValueKey('mangaPaged-$_loadSeq')`
  /// （_buildPagedContent）强制重建——语义等价「token 失配 → 丢弃结果」，
  /// 无需引入参考版 Empty/Loading/Ready/Failed 四态状态机。
  int _loadSeq = 0;

  /// [P4-3 E4] 当前错误是否为「章级」错误（章节正文获取失败 / 非卷章
  /// 0 图校验失败）：ErrorView 重试只重载当前章节 [_loadChapterImages]
  /// （对齐参考版 RetryChapter L308-318 章级重载，不重拉书籍信息/目录）；
  /// false = 书级错误（书籍信息/目录获取失败），重试走整书重载 [_loadBook]
  bool _errorChapterLevel = false;

  /// [P4-3 E1] 翻页模式（**有效值**，对齐参考版 MangaScrollMode；默认条漫 4）
  ///
  /// [漫画设置作用域] 有效值 = 书级覆盖 ?? 全局值（[_applyEffectiveMangaScope]）
  int _scrollMode = MangaScrollModes.defaultValue;

  /// [P4-3 E1] 单页式 PageController（模式/章节/初始页变化时重建）
  PageController? _pagedController;

  /// [P4-3 E1] 控制器当前规格（轴/是否右起/所属代数），用于判定是否需重建
  Axis _pagedAxis = Axis.horizontal;
  bool _pagedReversed = false;
  int _pagedGen = 0;

  /// [P4-3 E5 / M5] 九区点击动作（9 格行优先；默认对齐参考版 Contract
  /// L167 [-1,-1,1,2,0,1,2,1,1]；经设置面板九宫格编辑器可改并持久化
  /// 于 [MangaConfigKeys.mangaClickActions]）
  List<int> _clickActions = MangaClickActions.defaultActions;

  /// [P4-3 E5] 点击按下位置（tap-up 时换算位移，区分点击与滑动/缩放意图）
  Offset? _tapDownPosition;

  /// [P4-3 E3] 自动翻页/自动滚动开关（会话态，不落库——对齐参考版
  /// MangaReaderContract L44 autoReadEnabled 默认 false 的会话态语义）
  bool _autoRead = false;

  /// [P4-3 E3] 自动翻页速度档 1..15（持久化；缺省/非法 → 默认 3，
  /// 对齐参考版 Contract L136 autoReadSpeed 默认 3）
  int _autoReadSpeed = MangaAutoRead.defaultValue;

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

  /// [P4-3 E2] 分页适配类型 0..5（持久化；缺省/非法 → 默认 0 = 全屏适配，
  /// 对齐参考版 Contract L121）
  int _pageScaleType = MangaPageScaleType.defaultValue;

  /// [P4-3 M3 修4] 条漫侧边留白百分比 0..45（**有效值**，默认 0；仅条漫渲染
  /// 路径消费：每侧 padding = 视口宽 × p/100，对齐参考版 MangaReaderScreen
  /// fraction = 1 - p×2/100 ⇔ itemWidth = 视口宽 × (1 - 2p/100)；
  /// 单页式路径不生效，设置面板仅 isWebtoon 显示此滑杆）
  ///
  /// [漫画设置作用域] 有效值 = 书级覆盖 ?? 全局值（[_applyEffectiveMangaScope]）
  int _sidePadding = 0;

  // ---------------------------------------------------------------------------
  // [漫画设置作用域 2026-10-01] 本书覆盖 + 全局回退（参考版仅 scrollMode 与
  // webtoon side padding 两项具备书级覆盖；长按存图/自动速度/九区点击动作
  // 保持全局，见 MangaConfigKeys 注释）。有效值优先级对齐参考版
  // MangaReaderViewModel L1332-1334 `book?.scrollMode ?: settings.scrollMode`。
  // ---------------------------------------------------------------------------

  /// 全局翻页模式（书级覆盖为空时的回退源；MangaConfigKeys.scrollMode）
  int _globalScrollMode = MangaScrollModes.defaultValue;

  /// 当前书书级翻页模式覆盖（`book.readConfig.mangaScrollMode`；
  /// null = 未覆盖，跟随全局）
  int? _bookScrollMode;

  /// 全局条漫侧边留白百分比 0..45（书级覆盖为空时的回退源；
  /// MangaConfigKeys.sidePadding）
  int _globalSidePadding = 0;

  /// 当前书书级条漫侧边留白覆盖（`book.readConfig.webtoonSidePaddingDp`；
  /// null = 未覆盖，跟随全局；数值沿用 Flutter 百分比口径 0..45）
  int? _bookSidePadding;

  // ---------------------------------------------------------------------------
  // [P4-3 M4 批2] 行为开关组（键名对齐原版 PreferKey，AppConfig.kt 默认值
  // 取证：disableClickScroll=false L906-907 / disableMangaScale=**true**
  // L880-881 / disableMangaPageAnim=false L892-893 / hideMangaTitle=false
  // L940-941 / volumeKeyPage=**true** L747-748 / reverseVolumeKeyPage=false
  // L749-750 / mangaLongClickSaveImage=**true** L886-887 /
  // disableMangaCrossFade=false（参考版 MangaSettings）；mangaBgColor 新增
  // 默认黑 0xFF000000（对齐原版 Scaffold 硬编码黑，默认行为零变化）
  // ---------------------------------------------------------------------------

  /// 禁用点击翻页（九区 1/2 失效，0/3/4 保留；对齐参考版 L1953/L714）
  bool _disableClickScroll = false;

  /// 禁用漫画缩放（true = InteractiveViewer 不渲染）
  bool _disableMangaScale = true;

  /// 禁用翻页动画（true = 单页 jumpToPage / 条漫 jumpTo 替代 animate；
  /// 自动翻页定时器条漫路径 animateTo 保留）
  bool _disableMangaPageAnim = false;

  /// 隐藏漫画列表标题（我方无章节标题页 → 映射 0 图卷章分隔页 +
  /// 章节导航区标题隐藏，按钮保留）
  bool _hideMangaTitle = false;

  /// 音量键翻页（平台无按键拦截通道 → 仅持久化，行为待平台支持）
  bool _volumeKeyPage = true;

  /// 反转音量键翻页方向（同上仅持久化）
  bool _reverseVolumeKeyPage = false;

  /// 长按保存图片（true = 长按直接 _savePageImage；false = 弹页操作菜单，
  /// 对齐原版 ReadMangaActivity L239-250 分支）
  bool _mangaLongClickSaveImage = true;

  /// 禁用加载淡入动画（false = 图片加载完成淡入，参考版 L1751 crossfade）
  bool _disableMangaCrossFade = false;

  /// 阅读背景色（ARGB 整型，Scaffold 底色 = 图片未覆盖区域底色）
  int _mangaBgColor = MangaBgColors.black;

  /// [P4-3 E2] 图片渲染 BoxFit：单页式按适配类型映射（Screen L1463-1472）；
  /// 条漫恒 fitWidth（Screen L1568）
  BoxFit get _imageFit => MangaScrollModes.isPaged(_scrollMode)
      ? MangaPageScaleType.fitFor(type: _pageScaleType)
      : MangaPageScaleType.webtoonFit;

  @override
  void initState() {
    super.initState();
    // [P4-3 M3 修2] 活跃 bookUrl 初始 = 入参（换源成功后更新）
    _activeBookUrl = widget.bookUrl;
    _preloader = ComicPreloadService(
      images: ref.read(bookImageRepositoryProvider),
      localBooks: ref.read(localBookServiceProvider),
      reading: ref.read(readingRepositoryProvider),
    );
    _scrollController.addListener(_onScroll);
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
  void dispose() {
    _preloader.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    // [P4-3 E3] 取消自动翻页定时器
    _autoReadTimer?.cancel();
    // [P4-3 M1] 菜单显隐动画控制器
    _menuCtrl.dispose();
    // [P4-3 E1] 单页式控制器（此时元素树已卸载，控制器已解绑，可安全释放）
    _pagedController?.dispose();
    // [P4-3 M5] 音量键捕获注销：退出阅读器立即关闭，防拦截范围
    // 外泄到其它页面（系统音量键恢复默认行为）
    final bridge = PlatformBridgeService.instance;
    bridge.unregisterVolumeKeyHandler();
    unawaited(bridge.setVolumeKeyCapture(false));
    // 退出前保存阅读进度
    unawaited(_saveProgress());
    unawaited(
      SystemBrightness.setFollowSystem(true).catchError((Object error) {
        debugPrint('退出漫画阅读时恢复系统亮度失败: $error');
      }),
    );
    super.dispose();
  }

  /// 加载漫画配置（config 键对齐原版 PreferKey）
  Future<void> _loadMangaConfig() async {
    try {
      final settings = await ref.read(mangaSettingsRepositoryProvider).load();
      if (!mounted) return;
      setState(() {
        _colorFilter = settings.colorFilter;
        _footerConfig = settings.footer;
        _enableEInk = settings.enableEInk;
        _enableGray = settings.enableGray;
        _eInkThreshold = settings.eInkThreshold;
        _globalScrollMode = settings.scrollMode;
        _autoReadSpeed = settings.autoReadSpeed;
        _pageScaleType = settings.pageScaleType;
        _globalSidePadding = settings.sidePadding;
        _disableClickScroll = settings.disableClickScroll;
        _disableMangaScale = settings.disableMangaScale;
        _disableMangaPageAnim = settings.disableMangaPageAnim;
        _hideMangaTitle = settings.hideMangaTitle;
        _volumeKeyPage = settings.volumeKeyPage;
        _reverseVolumeKeyPage = settings.reverseVolumeKeyPage;
        _mangaLongClickSaveImage = settings.longClickSaveImage;
        _disableMangaCrossFade = settings.disableCrossFade;
        _mangaBgColor = settings.backgroundColor;
        _clickActions = settings.clickActions;
      });
      // [漫画设置作用域] 配置可能在图片加载后才生效：按书级 ?? 全局重算
      // 有效翻页模式/侧边留白（内部同步单页式控制器与自动翻页定时器）
      _applyEffectiveMangaScope();
      // [P4-3 M5] 音量键捕获同步（开关开启时注册，对齐原版阅读器内拦截）
      _syncVolumeKeyCapture();
      await _applyBrightness(_colorFilter.l);
    } catch (_) {}
  }

  /// [漫画设置作用域] 重算并应用有效漫画设置：书级覆盖 > 全局 > 默认。
  ///
  /// - 翻页模式：`book.readConfig.mangaScrollMode` 非 null 优先，否则回退
  ///   全局 [MangaConfigKeys.scrollMode]（对齐参考版 MangaReaderViewModel
  ///   L1332 `book?.scrollMode ?: settings.scrollMode`）；
  /// - 条漫侧边留白：`book.readConfig.webtoonSidePaddingDp` 非 null 优先，
  ///   否则回退全局 [MangaConfigKeys.sidePadding]；数值沿用 Flutter 既有
  ///   百分比口径 0..45（与参考版 dp 字段仅作用域对齐，不做单位换算）。
  ///
  /// 模式变化时同步单页式控制器与自动翻页定时器；仅留白变化时 setState
  /// 重建条漫列表即生效。
  void _applyEffectiveMangaScope() {
    final mode = _bookScrollMode ?? _globalScrollMode;
    final padding = _bookSidePadding ?? _globalSidePadding;
    final modeChanged = mode != _scrollMode;
    final paddingChanged = padding != _sidePadding;
    if (!modeChanged && !paddingChanged) return;
    _scrollMode = mode;
    _sidePadding = padding;
    if (mounted) setState(() {});
    if (modeChanged) {
      _applyScrollMode();
      // [P4-3 E3] 翻页模式决定自动定时器语义（单页/条漫），变更后重启
      _restartAutoReadTimer();
    }
  }

  /// [漫画设置作用域] 持久化**全局**翻页模式并即时应用（作用域 = 全局时
  /// 的写入路径；书级覆盖存在时仅更新全局回退值，不改变屏内有效值——
  /// 对齐参考版 MangaSettings.scrollMode 与书级 `mangaScrollMode` 分层）
  Future<void> _persistScrollMode(int mode) async {
    final v = MangaScrollModes.valid.contains(mode)
        ? mode
        : MangaScrollModes.defaultValue;
    _globalScrollMode = v;
    _applyEffectiveMangaScope();
    try {
      await ref
          .read(mangaSettingsRepositoryProvider)
          .update((s) => s.copyWith(scrollMode: v));
    } catch (_) {}
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

  /// [P4-3 M5] 九区点击动作循环切换并持久化（对齐参考版
  /// UpdateClickAction → nextMangaClickAction 循环 -1→0→1→2→3→4→-1）
  Future<void> _cycleClickAction(int index) async {
    if (index < 0 || index >= _clickActions.length) return;
    final next = MangaClickActions.cycleNext(_clickActions[index]);
    final updated = List<int>.from(_clickActions)..[index] = next;
    if (mounted) setState(() => _clickActions = updated);
    try {
      await ref
          .read(mangaSettingsRepositoryProvider)
          .update((s) => s.copyWith(clickActions: updated));
    } catch (_) {}
  }

  /// [P4-3 E3] 持久化自动翻页速度档并重启定时器（1..15，越限收敛）
  Future<void> _persistAutoReadSpeed(int speed) async {
    final v = MangaAutoRead.parse('$speed');
    if (v == _autoReadSpeed) return;
    if (mounted) setState(() => _autoReadSpeed = v);
    _restartAutoReadTimer();
    try {
      await ref
          .read(mangaSettingsRepositoryProvider)
          .update((s) => s.copyWith(autoReadSpeed: v));
    } catch (_) {}
  }

  /// [P4-3 E2] 持久化分页适配类型（0..5，缺省/非法回退 0；
  /// 对齐参考版 MangaReaderViewModel L816 PAGE_SCALE_TYPE 持久化）
  Future<void> _persistPageScaleType(int type) async {
    final v = MangaPageScaleType.parse('$type');
    if (v == _pageScaleType) return;
    if (mounted) setState(() => _pageScaleType = v);
    try {
      await ref
          .read(mangaSettingsRepositoryProvider)
          .update((s) => s.copyWith(pageScaleType: v));
    } catch (_) {}
  }

  /// [漫画设置作用域] 持久化**全局**条漫侧边留白（0..45%，越限收敛；
  /// 作用域 = 全局时的写入路径；仅条漫渲染路径生效——条漫 ListView 包
  /// 水平 padding，单页式不受影响；setState 即时重建条漫子树使滑杆拖动
  /// 实时生效）
  Future<void> _persistSidePadding(int value) async {
    final v = value.clamp(0, 45);
    _globalSidePadding = v;
    _applyEffectiveMangaScope();
    try {
      await ref
          .read(mangaSettingsRepositoryProvider)
          .update((s) => s.copyWith(sidePadding: v));
    } catch (_) {}
  }

  /// [漫画设置作用域] 写入/清除当前书**书级**翻页模式覆盖。
  ///
  /// [value] null = 清除覆盖（删 `readConfig.mangaScrollMode` 键，跟随全局；
  /// 对齐参考版「跟随全局」语义——不写入默认值冒充清除）。
  Future<void> _persistBookScrollMode(int? value) async {
    final v = value == null
        ? null
        : (MangaScrollModes.valid.contains(value)
              ? value
              : MangaScrollModes.defaultValue);
    if (!await _updateBookReadConfigField('mangaScrollMode', v)) return;
    _bookScrollMode = v;
    _applyEffectiveMangaScope();
  }

  /// [漫画设置作用域] 写入/清除当前书**书级**条漫侧边留白覆盖
  /// （百分比口径 0..45，越限收敛；键名 `webtoonSidePaddingDp` 对齐参考版，
  /// 数值不做 dp 换算）。[value] null = 清除覆盖，跟随全局。
  Future<void> _persistBookSidePadding(int? value) async {
    final v = value?.clamp(0, 45);
    if (!await _updateBookReadConfigField('webtoonSidePaddingDp', v)) return;
    _bookSidePadding = v;
    _applyEffectiveMangaScope();
  }

  /// [漫画设置作用域] 单字段局部更新当前书 readConfig（保留其他 readConfig
  /// 成员、章节与进度字段，避免整书陈旧快照覆盖）：
  /// 1. 先重取当前书（`_activeBookUrl`）拿最新快照；
  /// 2. 仅在 readConfig JSON 上增/删目标键（null = 删键清除书级覆盖）；
  /// 3. 经现有 [BookshelfRepository.updateBook] + [Book.copyWith] 落库，并同步屏内
  ///    [_book] 缓存供后续写入使用。
  ///
  /// 返回是否写入成功（失败不改变屏内书级覆盖态）。
  Future<bool> _updateBookReadConfigField(String key, int? value) async {
    try {
      final fresh = await ref
          .read(bookshelfRepositoryProvider)
          .getBook(_activeBookUrl);
      if (fresh == null) return false;
      final map = Map<String, dynamic>.from(
        fresh.readConfig?.toJson() ?? const <String, dynamic>{},
      );
      if (value == null) {
        map.remove(key);
      } else {
        map[key] = value;
      }
      final updated = fresh.copyWith(
        readConfig: map.isEmpty ? null : ReadConfig.fromJson(map),
      );
      await ref.read(bookshelfRepositoryProvider).updateBook(updated);
      _book = updated;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// [P4-3 M4 批2] 持久化行为开关（8 键通用：setState 即时生效 +
  /// setConfig 落库，键名对齐原版 PreferKey）
  Future<void> _persistMangaBool(
    MangaToggle option,
    bool value,
    void Function(bool) apply,
  ) async {
    apply(value);
    if (mounted) setState(() {});
    try {
      await ref
          .read(mangaSettingsRepositoryProvider)
          .update((s) => s.withToggle(option, value));
    } catch (_) {}
  }

  /// [P4-3 M4 批2] 持久化阅读背景色（ARGB 整型 → 十进制字符串；
  /// setState 即时重建 Scaffold 使色板点选实时生效）
  Future<void> _persistMangaBgColor(int argb) async {
    if (argb < 0 || argb > 0xFFFFFFFF) return;
    if (argb == _mangaBgColor) return;
    if (mounted) setState(() => _mangaBgColor = argb);
    try {
      await ref
          .read(mangaSettingsRepositoryProvider)
          .update((s) => s.copyWith(backgroundColor: argb));
    } catch (_) {}
  }

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
  /// - 条漫式（4/5）→ 释放单页式控制器（条漫控制器保留偏移，重新附着时
  ///   自然恢复位置，缩放/磁盘缓存/预载路径不变）。
  void _applyScrollMode() {
    if (MangaScrollModes.isPaged(_scrollMode)) {
      final n = _imageUrls.length;
      if (n == 0) return; // 图片未就绪：_loadChapterImages 完成后会再同步
      // 待恢复的页级进度优先（单页式定位由控制器 initialPage 完成，此处消费）
      final initial = (_restorePageIndex ?? _visiblePageIndex).clamp(0, n - 1);
      _restorePageIndex = null;
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

  Future<void> _persistColorFilter(MangaColorFilterConfig cfg) async {
    _colorFilter = MangaColorFilterConfig(
      r: cfg.r,
      g: cfg.g,
      b: cfg.b,
      a: cfg.a,
      l: cfg.l,
    );
    setState(() {});
    try {
      await ref
          .read(mangaSettingsRepositoryProvider)
          .update((s) => s.copyWith(colorFilter: _colorFilter));
    } catch (_) {}
    await _applyBrightness(_colorFilter.l);
  }

  Future<void> _persistFooter(MangaFooterConfig cfg) async {
    _footerConfig = MangaFooterConfig.fromJson(cfg.toJson());
    setState(() {});
    try {
      await ref
          .read(mangaSettingsRepositoryProvider)
          .update((s) => s.copyWith(footer: _footerConfig));
    } catch (_) {}
  }

  Future<void> _persistEInk(bool enabled) async {
    setState(() {
      _enableEInk = enabled;
      if (enabled) _enableGray = false;
    });
    try {
      await ref
          .read(mangaSettingsRepositoryProvider)
          .update(
            (s) => s.copyWith(
              enableEInk: enabled,
              enableGray: enabled ? false : s.enableGray,
            ),
          );
    } catch (_) {}
  }

  Future<void> _persistGray(bool enabled) async {
    setState(() {
      _enableGray = enabled;
      if (enabled) _enableEInk = false;
    });
    try {
      await ref
          .read(mangaSettingsRepositoryProvider)
          .update(
            (s) => s.copyWith(
              enableGray: enabled,
              enableEInk: enabled ? false : s.enableEInk,
            ),
          );
    } catch (_) {}
  }

  Future<void> _persistThreshold(int value) async {
    setState(() => _eInkThreshold = value.clamp(0, 255));
    try {
      await ref
          .read(mangaSettingsRepositoryProvider)
          .update((s) => s.copyWith(eInkThreshold: _eInkThreshold));
    } catch (_) {}
  }

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
      onColorFilterChanged: (c) => unawaited(_persistColorFilter(c)),
      onFooterChanged: (c) => unawaited(_persistFooter(c)),
      onEnableEInkChanged: (v) => unawaited(_persistEInk(v)),
      onEnableGrayChanged: (v) => unawaited(_persistGray(v)),
      onEInkThresholdChanged: (v) => unawaited(_persistThreshold(v)),
      onScrollModeChanged: (m) => unawaited(_persistScrollMode(m)),
      onAutoReadChanged: (v) => _setAutoReadEnabled(v),
      onAutoReadSpeedChanged: (v) => unawaited(_persistAutoReadSpeed(v)),
      // [P4-3 E2] 分页适配类型变更持久化（对齐参考版 ViewModel L816）
      onPageScaleTypeChanged: (v) => unawaited(_persistPageScaleType(v)),
      // [P4-3 M3 修4] 条漫侧边留白（条漫专属滑杆，0..45% 持久化）
      sidePadding: _sidePadding,
      onSidePaddingChanged: (v) => unawaited(_persistSidePadding(v)),
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
      // PreferKey，持久化经 _persistMangaBool / _persistMangaBgColor）
      disableClickScroll: _disableClickScroll,
      disableMangaScale: _disableMangaScale,
      disableMangaPageAnim: _disableMangaPageAnim,
      hideMangaTitle: _hideMangaTitle,
      volumeKeyPage: _volumeKeyPage,
      reverseVolumeKeyPage: _reverseVolumeKeyPage,
      mangaLongClickSaveImage: _mangaLongClickSaveImage,
      disableMangaCrossFade: _disableMangaCrossFade,
      mangaBgColor: _mangaBgColor,
      onDisableClickScrollChanged: (v) => unawaited(
        _persistMangaBool(
          MangaToggle.disableClickScroll,
          v,
          (x) => _disableClickScroll = x,
        ),
      ),
      onDisableMangaScaleChanged: (v) => unawaited(
        _persistMangaBool(
          MangaToggle.disableMangaScale,
          v,
          (x) => _disableMangaScale = x,
        ),
      ),
      onDisableMangaPageAnimChanged: (v) => unawaited(
        _persistMangaBool(
          MangaToggle.disableMangaPageAnim,
          v,
          (x) => _disableMangaPageAnim = x,
        ),
      ),
      onHideMangaTitleChanged: (v) => unawaited(
        _persistMangaBool(
          MangaToggle.hideMangaTitle,
          v,
          (x) => _hideMangaTitle = x,
        ),
      ),
      onVolumeKeyPageChanged: (v) => unawaited(
        _persistMangaBool(MangaToggle.volumeKeyPage, v, (x) {
          _volumeKeyPage = x;
          // [P4-3 M5] 开关即时启停捕获（关闭立即恢复系统音量键）
          _syncVolumeKeyCapture();
        }),
      ),
      onReverseVolumeKeyPageChanged: (v) => unawaited(
        _persistMangaBool(
          MangaToggle.reverseVolumeKeyPage,
          v,
          (x) => _reverseVolumeKeyPage = x,
        ),
      ),
      onMangaLongClickSaveImageChanged: (v) => unawaited(
        _persistMangaBool(
          MangaToggle.longClickSaveImage,
          v,
          (x) => _mangaLongClickSaveImage = x,
        ),
      ),
      onDisableMangaCrossFadeChanged: (v) => unawaited(
        _persistMangaBool(
          MangaToggle.disableCrossFade,
          v,
          (x) => _disableMangaCrossFade = x,
        ),
      ),
      onMangaBgColorChanged: (v) => unawaited(_persistMangaBgColor(v)),
      // [P4-3 M5] 九宫格点击区编辑器（对齐参考版 ClickActionsSettingsContent
      // L772-802：点击循环切换；单格索引回调，屏内即时生效）
      clickActions: _clickActions,
      onClickActionChanged: (index) => unawaited(_cycleClickAction(index)),
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
      Navigator.of(context)
          .pushNamed(AppRoutes.changeSource, arguments: book)
          .then((dynamic result) {
            final newBookUrl = result is String ? result : null;
            if (newBookUrl == null || newBookUrl.isEmpty || !mounted) return;
            setState(() {
              _activeBookUrl = newBookUrl;
              // 整书重载归位：章首开始、清页级恢复锚定与可见页估算
              _currentChapterIndex = 0;
              _restorePageIndex = null;
              _visiblePageIndex = 0;
            });
            // 代数换代：中止在飞相邻章预载 + 单页式子树强制重建
            _loadSeq++;
            unawaited(_loadBook());
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
    // 条漫：按页比例估算像素跳转（与 [_onScroll] 的可见页近似公式
    // ratio×(n-1) 自洽，跳后 _onScroll 回读一致）
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final max = position.maxScrollExtent;
    if (max <= 0) return;
    final targetPixels = n > 1 ? max * target / (n - 1) : 0.0;
    if ((targetPixels - position.pixels).abs() < 1) return; // 已在目标
    position.jumpTo(targetPixels);
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

  /// 加载书籍信息和章节列表
  Future<void> _loadBook() async {
    setState(() {
      _loading = true;
      _error = null;
      _errorChapterLevel = false; // [P4-3 E4] 书级重载入口复位章级错误标记
    });

    try {
      // 获取书籍信息（[P4-3 M3 修2] 走活跃 bookUrl，换源后按新源重载）
      _book = await ref
          .read(bookshelfRepositoryProvider)
          .getBook(_activeBookUrl);
      if (_book == null) {
        setState(() {
          _error = '未找到书籍信息';
          _loading = false;
        });
        return;
      }

      // [漫画设置作用域] 重装当前书书级覆盖（切书/换源/整书重载统一入口：
      // 书级非 null 覆盖全局、null 回退全局；非法模式/越界留白按归一规则
      // 降级为「未覆盖」，避免旧屏幕状态污染新书）
      final bookReadConfig = _book!.readConfig;
      final rawScrollMode = bookReadConfig?.mangaScrollMode;
      _bookScrollMode =
          (rawScrollMode != null &&
              MangaScrollModes.valid.contains(rawScrollMode))
          ? rawScrollMode
          : null;
      _bookSidePadding = bookReadConfig?.webtoonSidePaddingDp?.clamp(0, 45);
      _applyEffectiveMangaScope();

      // 获取章节列表。对齐原版 / reader_notifier / toc_screen：
      // 本地库无目录的在线书（搜索进详情未落库章节、或 notShelf 临时书）
      // 须自动 refreshToc，否则漫画阅读器永远「暂无章节」无法进正文/图片。
      // 设备实测：51漫画 book.type=notShelf|image、chapters=0，Rust 侧
      // refresh_toc 可出 1 章+正文图，缺此回退则整链断裂。— Reasonix + UI
      _chapters = await ref
          .read(readingRepositoryProvider)
          .getChapters(_activeBookUrl);
      if (_chapters.isEmpty &&
          _book != null &&
          _book!.origin.isNotEmpty &&
          !_book!.origin.startsWith(BookType.localTag) &&
          !_book!.origin.startsWith(BookType.webDavTag)) {
        _chapters = await ref
            .read(readingRepositoryProvider)
            .refreshToc(_activeBookUrl, _book!.origin);
      }
      if (_chapters.isEmpty) {
        setState(() {
          _error = '暂无章节';
          _loading = false;
        });
        return;
      }

      // 恢复上次阅读位置
      _currentChapterIndex = _book!.durChapterIndex;
      if (_currentChapterIndex >= _chapters.length) {
        _currentChapterIndex = 0;
      }

      // [P4-1 C1] 记住记录的页级进度（重开定位页；0/缺省 = 章首）
      _restorePageIndex = _book!.durChapterPos > 0
          ? _book!.durChapterPos
          : null;
      // [P4-1 C3] 代数守卫：换书/重载后失效在途的相邻章预载
      _loadSeq++;

      // 加载当前章节的图片
      await _loadChapterImages();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        // BridgeError 无自定义 toString()，裸显会显示 "Instance of 'BridgeError'"
        _error = errorMessage(e);
        _loading = false;
      });
    }
  }

  /// 加载当前章节的图片 URL 列表
  Future<void> _loadChapterImages() async {
    if (_chapters.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
      _errorChapterLevel = false; // [P4-3 E4] 章级重载入口复位章级错误标记
      _imageUrls = [];
      _preloader.reset();
      _failedIndices.clear();
    });

    try {
      final chapter = _chapters[_currentChapterIndex];

      // 书源防盗链 header（仅取一次；对齐原版 OkHttpStreamFetcher 带书源
      // headerMap 加载漫画图）+ 书源对象（imageDecode 规则判断）— Reasonix
      if ((_imageHeaders.isEmpty || _bookSource == null) &&
          _book != null &&
          _book!.origin.isNotEmpty) {
        final sources = await ref
            .read(bookSourceRepositoryProvider)
            .getBookSources();
        for (final s in sources) {
          if (s.bookSourceUrl == _book!.origin) {
            _bookSource = s;
            if (s.header != null && s.header!.isNotEmpty) {
              _imageHeaders = _parseHeaderMap(s.header!);
            }
            break;
          }
        }
      }

      // 获取章节内容
      String content;
      if (chapter.url.isNotEmpty && _book != null) {
        // 在线章节：通过 fetchChapterContent 获取（[P4-3 M3 修2] 活跃 bookUrl）
        content = await ref
            .read(readingRepositoryProvider)
            .fetchChapterContent(_activeBookUrl, chapter.url, _book!.origin);
      } else {
        // 本地章节：通过 getChapterContent 获取
        content = await ref
            .read(readingRepositoryProvider)
            .getChapterContent(_activeBookUrl, _currentChapterIndex);
      }

      if (!mounted) return;

      // 解析图片 URL（支持多种格式）
      _imageUrls = _parseImageUrls(content);

      // 相对路径转绝对（对齐原版 BookHelp.flowImages：
      // NetworkUtils.getAbsoluteURL(bookChapter.url, src)）— Reasonix
      // [cbz 批 D] 本地 cbz 页为 `cbz://` 伪 URL：不参与相对路径换算
      //（cbz 章节 url 为空，换算会把伪 URL 破坏成 `/cbz://...`）
      if (_imageUrls.any(
        (u) => !u.startsWith('http') && !u.startsWith('cbz://'),
      )) {
        _imageUrls = _imageUrls
            .map((u) => _resolveImageUrl(chapter.url, u))
            .toList();
      }

      // 如果章节有 imgUrl 字段，也作为图片源
      if (chapter.imgUrl != null && chapter.imgUrl!.isNotEmpty) {
        _imageUrls.insert(0, chapter.imgUrl!);
      }

      setState(() {
        _loading = false;
      });

      // [P4-3 E4] 0 图章节校验（对齐原版 ReadManga.kt L227-230
      // contentLoadFinish：imageCount==0 && !isVolume → loadFail「正文没有
      // 图片」；参考版 MangaChapterPageLoader L36-38 同条件 throw →
      // Failed 态 → 全屏错误 + 章级重试 MangaReaderOverlays L757-771）：
      // - 非卷章：进入章级错误态（ErrorView + 重试，重试只重载当前章）
      // - 卷章（isVolume）：0 图是合法分隔页（原版 L635-636 ReaderLoading
      //   分隔页、标题=章名；参考版 L452-460 ChapterEdge "volume:..."
      //   message=chapterTitle）→ 非错误，_buildContent 显示章节标题
      //   + 上下章导航
      // 0 图无图片项：跳过分页控制器创建/预载/进度恢复，直接返回
      if (_imageUrls.isEmpty) {
        if (!_chapters[_currentChapterIndex].isVolume) {
          setState(() {
            _error = '正文没有图片';
            _errorChapterLevel = true;
          });
        }
        return;
      }

      // [P4-3 E1] 单页式：图片可见前创建 PageController
      //（初始页 = 待恢复页或章首；须在 _applyPageRestore 消费 _restorePageIndex 前取值）
      if (MangaScrollModes.isPaged(_scrollMode) && _imageUrls.isNotEmpty) {
        final initial = (_restorePageIndex ?? 0).clamp(
          0,
          _imageUrls.length - 1,
        );
        _visiblePageIndex = initial; // 页脚/进度回读一致
        _syncPagedController(initialLogical: initial);
      }

      // 触发初始预加载
      _preloadVisibleImages();

      // [P4-1 C1] 恢复记录的页级进度（定位到记录页）
      _applyPageRestore();
      // [P4-1 C3] 当前章加载完成后后台预载相邻章（下一章优先、静默失败）
      unawaited(_preloadAdjacentChapters());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        // BridgeError 无自定义 toString()，裸显会显示 "Instance of 'BridgeError'"
        _error = errorMessage(e);
        // [P4-3 E4] 章节正文获取失败 = 章级错误：重试只重载当前章
        // （对齐参考版 chapterLoaded 失败 → Failed(token, message) →
        // RetryChapter 章级重试，不重拉书籍信息/目录）
        _errorChapterLevel = true;
        _loading = false;
      });
    }
  }

  /// 从章节内容中解析图片 URL 列表（复合 URL 对齐原版 HtmlFormatter）
  /// — Reasonix + UI
  ///
  /// [cbz 批 D | 2026-10-03] 本地 `.cbz` 书正文是 Rust `get_chapter_content`
  /// 产出的 `cbz://<条目名>` 行列表；共享解析器 [parseComicImageUrls] 的行
  /// 解析要求 `http` 前缀（comic_image_utils.dart L82），不认 cbz scheme。
  /// 在屏内先按行提取 `cbz://` 伪 URL 直用（改动最小：不引入本地书语义
  /// 到共享解析器，避免影响文本阅读器兜底 isImageDominantContent 的
  /// 既有 http 行为）。— 全栈工程师 + UI
  List<String> _parseImageUrls(String content) {
    final cbzEntries = _extractCbzEntries(content);
    if (cbzEntries.isNotEmpty) return cbzEntries;
    return parseComicImageUrls(content);
  }

  /// 提取 `cbz://` 行（逐行 trim；保持 Rust 自然排序与原始条目名）
  List<String> _extractCbzEntries(String content) {
    if (!content.contains('cbz://')) return const [];
    final entries = <String>[];
    for (final line in content.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.startsWith('cbz://')) entries.add(trimmed);
    }
    return entries;
  }

  /// 相对路径转绝对（以章节 URL 为 base，对齐原版 NetworkUtils.getAbsoluteURL）
  String _resolveImageUrl(String chapterUrl, String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('//')) return 'https:$url';
    final uri = Uri.tryParse(chapterUrl);
    if (uri == null) return url;
    final base = uri.scheme.isNotEmpty && uri.host.isNotEmpty
        ? '${uri.scheme}://${uri.host}'
        : chapterUrl;
    if (url.startsWith('/')) return '$base$url';
    // 相对当前目录：章节 URL 去掉最后一段
    final path = uri.path;
    final dir = path.substring(0, path.lastIndexOf('/') + 1);
    return '$base$dir$url';
  }

  /// 滚动监听，触发预加载
  void _onScroll() {
    // [P4-1 C1] 区分「恢复跳转」与「用户滚动」：jumpTo 触发的本次滚动
    // 不终止页级恢复锚定；用户手动滚动则消费待恢复目标（已离开记录页）
    final fromRestoreJump = _isRestoreJump;
    _isRestoreJump = false;
    if (!fromRestoreJump && _restorePageIndex != null) {
      _restorePageIndex = null;
    }
    if (_imageUrls.isNotEmpty && _scrollController.hasClients) {
      final max = _scrollController.position.maxScrollExtent;
      if (max > 0) {
        final ratio = (_scrollController.offset / max).clamp(0.0, 1.0);
        final page = (ratio * (_imageUrls.length - 1)).round();
        if (page != _visiblePageIndex) {
          setState(() => _visiblePageIndex = page);
          // [P4-1 C1] 页级进度：可见页变化即持久化（对齐文本阅读器
          // 「每次页级位置变化保存一次」的事件驱动频率，非逐帧写入）
          unawaited(_saveProgress());
        }
      }
    }
    _preloadVisibleImages();
  }

  /// 滚动度量（内容高度）变化监听 — [P4-1 C1]
  ///
  /// 图片解码期间内容高度不稳定（占位 → 0 → 实际），[ScrollMetricsNotification]
  /// 在度量变化时派发（注意：控制器 listener 收不到纯度量变化，须用
  /// Notification）。仍有待应用/锚定的页级恢复目标时，postFrame 里把视图
  /// 重新锚定到记录页（布局阶段 jumpTo 无效，须推迟到帧结束）。
  bool _onScrollMetricsChanged(ScrollMetricsNotification notification) {
    if (_restorePageIndex != null && !_isRestoreJump) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _jumpToRestoredPage();
      });
    }
    return false;
  }

  /// [P4-1 C1] 应用页级进度恢复：定位到 durChapterPos 记录页
  ///
  /// 对齐原版 ReadManga.upData/buildMangaContent：重开恢复记录页
  /// （clamped 到 [0, imageCount-1]）。首跳在 postFrame 里执行（确保
  /// ListView 已构建）；图片解码改变滚动范围时由 [_onScrollMetrics]
  /// 补跳一次后消费。
  void _applyPageRestore() {
    final target = _restorePageIndex;
    _restorePageIndex = null;
    if (target == null || _imageUrls.length < 2) return;
    final page = target.clamp(0, _imageUrls.length - 1);
    if (page == 0) return; // 章首 = 默认位置，无需跳转
    if (MangaScrollModes.isPaged(_scrollMode)) {
      // [P4-3 E1] 单页式：定位已由 PageController.initialPage 完成
      //（_loadChapterImages 同步控制器时消费），无需 ListView 跳转锚定
      return;
    }
    _restorePageIndex = page; // 保持待应用：滚动范围稳定后补跳
    _jumpToRestoredPage();
  }

  /// [P4-1 C1] 跳到记录页（按页比例估算，与 [_onScroll] 的可见页近似
  /// 公式自洽，页脚/进度回读一致）
  ///
  /// 不在此消费 [_restorePageIndex]：图片解码后内容高度仍会变化，由
  /// [_onScrollMetricsChanged] 的度量变化继续把视图锚定到记录页；用户
  /// 手动滚动时由 [_onScroll] 消费（终止锚定）。
  void _jumpToRestoredPage() {
    final page = _restorePageIndex;
    if (page == null || _imageUrls.length < 2) return;
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    if (max <= 0) return;
    // 标记为恢复跳转：jumpTo 同步触发的 [_onScroll] 不误判为用户滚动
    _isRestoreJump = true;
    _scrollController.jumpTo(max * page / (_imageUrls.length - 1));
  }

  Future<void> _preloadAdjacentChapters() => _preloader.preloadAdjacent(
    bookUrl: _activeBookUrl,
    chapterIndex: _currentChapterIndex,
    chapterCount: _chapters.length,
  );

  /// 预加载当前可见区域前后的图片。
  ///
  /// 有书源 / 复合 URL / imageDecode 时与正式渲染统一走 FFI
  /// `fetchImageWithDecode`（写入 [ComicImageDecodeCache]），禁止
  /// CachedNetworkImageProvider 旁路（会截断复合 URL 或忽略防盗链）。
  /// — Reasonix + UI
  void _preloadVisibleImages() {
    if (_imageUrls.isEmpty || !mounted) return;
    // [P4-3 E1] 单页式：按精确页索引预载（±2 页），无需比例估算
    if (MangaScrollModes.isPaged(_scrollMode)) {
      _preloadIndicesInRange(
        _visiblePageIndex - _preloadRange,
        _visiblePageIndex + _preloadRange,
      );
      return;
    }
    // 防御：loading 态 ListView 尚未构建时 ScrollController 未 attach，
    // 访问 position 抛断言（加载完成 build 后由 _onScroll 再次触发）
    if (!_scrollController.hasClients) return;

    // 计算当前可见的图片索引范围
    final viewportHeight = _scrollController.position.viewportDimension;
    final scrollOffset = _scrollController.offset;

    // 简单估算：假设每张图高度约为屏幕高度
    final screenHeight = MediaQuery.of(context).size.height;
    final firstVisible = (scrollOffset / screenHeight).floor().clamp(
      0,
      _imageUrls.length - 1,
    );
    final lastVisible = ((scrollOffset + viewportHeight) / screenHeight)
        .ceil()
        .clamp(0, _imageUrls.length - 1);

    // 扩展预加载范围（前后各 2 页）
    _preloadIndicesInRange(
      firstVisible - _preloadRange,
      lastVisible + _preloadRange,
    );
  }

  void _preloadIndicesInRange(int start, int end) {
    if (!mounted) return;
    unawaited(
      _preloader.preloadRange(
        urls: _imageUrls,
        start: start,
        end: end,
        bookUrl: _activeBookUrl,
        book: _book,
        source: _bookSource,
        precacheNetwork: (url) =>
            precacheImage(CachedNetworkImageProvider(url), context),
      ),
    );
  }

  /// 解析书源 header 字符串（JSON 或 key: value 行）— Reasonix
  Map<String, String> _parseHeaderMap(String header) {
    final trimmed = header.trim();
    if (trimmed.isEmpty) return const {};
    if (trimmed.startsWith('{')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) {
          return decoded.map((k, v) => MapEntry(k, v.toString()));
        }
      } catch (_) {
        // JSON 解析失败走行解析
      }
    }
    final map = <String, String>{};
    for (final line in trimmed.split('\n')) {
      final idx = line.indexOf(':');
      if (idx > 0) {
        map[line.substring(0, idx).trim()] = line.substring(idx + 1).trim();
      }
    }
    return map;
  }

  /// 切换到指定章节
  Future<void> _goToChapter(int index) async {
    if (index < 0 || index >= _chapters.length) return;
    // 切章前保存旧章的页级进度（_visiblePageIndex 仍指向旧章可见页）
    await _saveProgress();
    _currentChapterIndex = index;
    _restorePageIndex = null; // 手动切章不应用初始页级恢复
    _visiblePageIndex = 0; // 新章从章首开始
    // [P4-3 W2-fix P0-2] 递增预载代数：使旧章在途预载失效（同 _loadBook
    // L565 先例），并令 [_syncPagedController] 的 _pagedGen == _loadSeq
    // 守卫失配 → 重建控制器 initialPage = 章首（对齐参考版
    // openChapter(index, pageIndex = 0) 新章恒从 0 页开始）。
    // 原实现不递增：切章后 PageView 以新图片列表卸载重挂时落回控制器
    // 构造时的 initialPage（即旧章恢复页），带页级进度恢复进入后
    // 每次切章都落旧页。
    _loadSeq++;
    // 滚动到顶部
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    await _loadChapterImages();
    // 新章章首进度（chapterPos=0，与 chapterIndex 一并落库）
    await _saveProgress();
  }

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

  /// 保存阅读进度
  ///
  /// [P4-1 C1] chapterPos 携带页级进度（当前可见页索引，clamp 到
  /// [0, imageCount-1]），替代修复前恒 0；对齐原版
  /// ReadManga.saveRead/buildMangaContent 的 durChapterPos 语义
  /// （与章级 durChapterIndex 一并落库，互不覆写）。
  Future<void> _saveProgress() async {
    try {
      final maxPage = _imageUrls.isEmpty ? 0 : _imageUrls.length - 1;
      final pos = _visiblePageIndex.clamp(0, maxPage);
      await ref
          .read(readingRepositoryProvider)
          .updateReadingProgress(
            bookUrl: _activeBookUrl,
            chapterIndex: _currentChapterIndex,
            chapterPos: pos,
          );
    } catch (_) {
      // 保存失败不阻断阅读流程
    }
  }

  /// 切换控制栏显示/隐藏
  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    // [P4-3 M1] 菜单滑入/滑出动画（隐藏时动画落定后子树移除，
    // 见 build 的 AnimatedBuilder）
    if (_showControls) {
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
    if (_disableClickScroll &&
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
    if (position.pixels <= 0) {
      unawaited(_prevChapter());
      return;
    }
    var target = position.pixels - position.viewportDimension;
    if (target < 0) {
      target = 0; // 滚完剩余距离（部分消费）
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
    // 隐藏「复制链接」项；保存/分享走 cbzReadPage 字节（见 _resolvePageImage）
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

  /// 解析当前页图片字节（内存缓存 → 磁盘缓存 → FFI 解码回退）
  ///
  /// [cbz 批 D | 2026-10-03] 本地 cbz 页：内存缓存键 = 活跃 bookUrl
  /// （与渲染/预载一致，非 origin），字节源经 [cbzPath] 走 cbzReadPage。
  /// — 全栈工程师 + UI
  Future<MangaPageImageBytes?> _resolvePageImage(int index) async {
    final url = _imageUrls[index];
    final isCbz = url.startsWith('cbz://');
    return resolveMangaPageImageBytes(
      images: ref.read(bookImageRepositoryProvider),
      localBooks: ref.read(localBookServiceProvider),
      bookUrl: _activeBookUrl,
      url: url,
      // 有书源才走 FFI 解码链路（对齐 _DecodedComicImage 的分发条件）
      sourceJson: _bookSource == null
          ? null
          : jsonEncode(_bookSource!.toJson()),
      // 本地 cbz 页：cbzReadPage 读条目（无书源，无磁盘/网络链路）
      cbzPath: isCbz ? _book?.bookUrl : null,
      memoryCached: ComicImageDecodeCache.get(
        isCbz ? _activeBookUrl : (_book?.origin ?? ''),
        url,
      ),
    );
  }

  /// 保存图片（对齐原版：用户选目录写入；取消选择时回退文档目录并提示，
  /// 先例 auto_task_screen saveFile → 文档目录兜底）
  ///
  /// [D2] 平台分派（根因：MuMu DownloadStorageProvider 拒写
  /// SecurityException × file_picker 8.3.7 仅 catch IOException →
  /// 未捕获异常抛主线程 FATAL，m4b_fatal_stack_d2.txt）：
  /// - Android：MediaStore 直写通道（Download/legado/，不弹 SAF 对话框）
  ///   → 成功 toast「已保存: Download/legado/<文件名>」；通道失败 /
  ///   API < 29 → 回退文档目录兜底（现有逻辑 + 现有 toast）；
  /// - iOS / 其他平台：保持现有 file_picker saveFile 路径
  ///   （[D1 修复] bytes 必传；取消返回 null → 文档目录兜底）。
  Future<void> _savePageImage(int index) async {
    final data = await _resolvePageImage(index);
    if (data == null) {
      _showPageActionSnackBar('无法获取图片数据');
      return;
    }
    final fileName =
        'manga-${DateTime.now().millisecondsSinceEpoch}${data.suffix}';
    final service = PlatformBridgeService.instance;
    if (service.useMediaStoreDownloads) {
      // [D2] Android：MediaStore 直写（不经 SAF，绕开 file_picker 崩溃链路）
      final saved = await service.saveImageToDownloads(fileName, data.bytes);
      if (saved != null) {
        _showPageActionSnackBar('已保存: $saved');
        return;
      }
      // 通道失败 / API < 29 → 兜底写应用文档目录（现有逻辑）
      try {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$fileName')
          ..writeAsBytesSync(data.bytes);
        _showPageActionSnackBar('已保存到文档目录: ${file.path}');
      } catch (e) {
        _showPageActionSnackBar('保存图片失败: $e');
      }
      return;
    }
    // iOS / 其他平台：现有 file_picker saveFile 路径
    try {
      // 新版插件负责写入 bytes 并返回 URI；页面不再次写入选中位置。
      // 取消时返回 null，继续沿用文档目录兜底。
      final path = await FilePicker.saveFile(
        dialogTitle: '保存图片',
        fileName: fileName,
        bytes: data.bytes,
      );
      if (path != null) {
        final location = path.scheme == 'file'
            ? path.toFilePath()
            : path.toString();
        _showPageActionSnackBar('已保存: $location');
      } else {
        // 用户取消目录选择 → 兜底写应用文档目录
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$fileName')
          ..writeAsBytesSync(data.bytes);
        _showPageActionSnackBar('已保存到文档目录: ${file.path}');
      }
    } catch (e) {
      _showPageActionSnackBar('保存图片失败: $e');
    }
  }

  /// 分享图片（对齐参考版 ShareImage：临时文件 + 系统分享面板；
  /// 先例 auto_task_screen 的文件分享）
  Future<void> _sharePageImage(int index) async {
    final data = await _resolvePageImage(index);
    if (data == null) {
      _showPageActionSnackBar('无法获取图片数据');
      return;
    }
    try {
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/manga-${DateTime.now().millisecondsSinceEpoch}${data.suffix}',
      );
      await file.writeAsBytes(data.bytes);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], subject: '漫画图片'),
      );
    } catch (e) {
      _showPageActionSnackBar('分享失败: $e');
    }
  }

  /// 复制图片
  ///
  /// 降级说明：参考版 CopyImage（ReadMangaActivity L150-154）用
  /// ClipData.newUri 复制 URI；本方依赖集无图片/URI 剪贴板同族包先例，
  /// 按文本剪贴板先例（about_screen L58 / audio_screen L834）复制图片链接。
  Future<void> _copyPageImage(int index) async {
    try {
      await Clipboard.setData(ClipboardData(text: _imageUrls[index]));
      _showPageActionSnackBar('已复制图片链接');
    } catch (_) {
      _showPageActionSnackBar('复制失败');
    }
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
      pageCount: _imageUrls.length,
      axis: MangaScrollModes.axisOf(_scrollMode),
      reversed: MangaScrollModes.isReversed(_scrollMode),
      onDisplayIndexChanged: _onPagedPageChanged,
      pageBuilder: (context, logicalPage) => _buildImageItem(logicalPage),
      navBuilder: (context) => _buildChapterNavigation(),
    );
  }

  /// 构建图片列表（纵向连续滚动 + 双指缩放）
  ///
  /// [P4-1 C1] 外层包 [NotificationListener] 监听 [ScrollMetricsNotification]：
  /// 内容高度随图片解码变化时派发该通知，驱动页级进度恢复的「持续锚定到
  /// 记录页」（ScrollController listener 收不到纯度量变化，须用 Notification）。
  /// [P4-3 M3 修4] 条漫路径按 [_sidePadding] 百分比加水平 padding
  /// （见方法尾部包裹逻辑）。
  Widget _buildImageList() => ComicWebtoonView(
    controller: _scrollController,
    pageCount: _imageUrls.length,
    pageBuilder: (_, index) => _buildImageItem(index),
    navigationBuilder: (_) => _buildChapterNavigation(),
    disableScale: _disableMangaScale,
    withGap: _scrollMode == MangaScrollModes.webtoonWithGap,
    sidePadding: MangaScrollModes.isWebtoon(_scrollMode) ? _sidePadding : 0,
    onMetricsChanged: _onScrollMetricsChanged,
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
