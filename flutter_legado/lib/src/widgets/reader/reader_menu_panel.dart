import '../app_menu.dart';
import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    hide Provider;

import '../../models/models.dart';
import '../../providers/reader/reader_notifier.dart';
import '../../providers/ui_settings/ui_settings_notifier.dart';
import '../../routes.dart';
import '../../screens/reader_config_panel.dart';
import 'change_source_flow.dart';
import 'reader_chapter_link.dart';
import 'reader_download_dialog.dart';

/// [UI_SYNC_REFACTOR S2-1] 阅读菜单单块底部面板（对齐参考 ReadBookMenuBar）
///
/// 结构：屏幕顶栏（返回/书名/换源/刷新正文/下载（离线缓存）/更多溢出 +
/// 章节信息块）→ 底部 Surface（进度滑条行 + 单行五键行动作行）。
/// 底部按钮按用户指定顺序排列：目录/全文搜索/自动翻页/朗读/设置。
/// 键集沿用参考 ReadButtonConfigDelegate.kt:197-203（
/// DEFAULT_ENABLED_BUTTON_IDS = search/auto_page/catalog/read_aloud/setting，
/// 显示顺序 ReadBookContract.kt:404+ ReadBookButtonIds；无第二页、无字号/
/// 亮度键；参考 showBrightnessView 默认 "0" 亮度隐藏，字号/亮度保留在读内
/// 入口 ReaderSettingsSheet / ReaderConfigPanel）。
/// 常挂载+双向动画（visible 驱动）。
class ReaderMenuPanel extends ConsumerStatefulWidget {
  final bool visible;
  final VoidCallback onBack;
  final VoidCallback onAddBookmark;
  final VoidCallback onOpenCatalog;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenAdvancedConfig;
  final VoidCallback onOpenContentSearch;
  final VoidCallback onReadAloud;
  final VoidCallback onToggleAutoPage;
  final VoidCallback onOpenReplaceRules;
  final bool showBrightnessView;
  final String progressBehavior;
  final ValueChanged<int>? onSeekPage;
  final bool styleFollowPage;

  const ReaderMenuPanel({
    super.key,
    required this.visible,
    required this.onBack,
    required this.onAddBookmark,
    required this.onOpenCatalog,
    required this.onOpenSettings,
    required this.onOpenAdvancedConfig,
    required this.onOpenContentSearch,
    required this.onReadAloud,
    required this.onToggleAutoPage,
    required this.onOpenReplaceRules,
    this.showBrightnessView = true,
    this.progressBehavior = 'chapter',
    this.onSeekPage,
    this.styleFollowPage = false,
  });

  @override
  ConsumerState<ReaderMenuPanel> createState() => _ReaderMenuPanelState();
}

class _ReaderMenuPanelState extends ConsumerState<ReaderMenuPanel>
    with SingleTickerProviderStateMixin {
  final Set<int> _dismissalPointers = {};
  bool _popupMenuOpen = false;

  void _onPopupMenuOpen() => setState(() => _popupMenuOpen = true);

  void _onPopupMenuClose() => setState(() => _popupMenuOpen = false);

  void _dismissFromPointer(int pointer) {
    setState(() => _dismissalPointers.add(pointer));
    ref.read(readerNotifierProvider.notifier).hideControls();
  }

  void _releaseDismissalPointer(int pointer) {
    if (_dismissalPointers.remove(pointer)) setState(() {});
  }

  // 进出场：进 220（fadeIn180 内含）/ 出 180（对齐参考 0.88 缩放族）
  late final AnimationController _menuController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    reverseDuration: const Duration(milliseconds: 180),
    value: widget.visible ? 1 : 0,
  );

  @override
  void didUpdateWidget(covariant ReaderMenuPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible != widget.visible) {
      if (!widget.visible) _popupMenuOpen = false;
      widget.visible ? _menuController.forward() : _menuController.reverse();
    }
  }

  @override
  void dispose() {
    _menuController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(readerNotifierProvider);
    final notifier = ref.read(readerNotifierProvider.notifier);
    final book = state.currentBook;
    final chapter =
        (state.chapters.isNotEmpty &&
            state.currentChapterIndex < state.chapters.length)
        ? state.chapters[state.currentChapterIndex]
        : null;
    final cs = Theme.of(context).colorScheme;
    final followColor = widget.styleFollowPage ? state.backgroundColor : null;
    final foreground = widget.styleFollowPage ? state.textColor : null;
    final adv = ref.watch(readerAdvConfigProvider);
    final autoPageActive = adv?.autoPageTurn ?? false;
    var barColor = followColor ?? cs.surface;
    // [UI_SYNC_REFACTOR S2-2] 表面 Haze 档（实色等效）：enableBlur 时
    // 半透明底（α 85/255，参考 readMenuBlurAlpha 默认）+ BackdropFilter(24)
    final ui = uiSettingsListenable.value;
    final useSurfaceBlur = ui.enableBlur && followColor == null;
    if (useSurfaceBlur) {
      barColor = barColor.withValues(alpha: 85 / 255);
    }

    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _menuController,
        builder: (context, child) {
          final v = _menuController.value;
          final hidden = v == 0 && !widget.visible;
          if (hidden && _dismissalPointers.isEmpty) {
            return const SizedBox.shrink();
          }
          final fade = Tween<double>(begin: 0, end: 1).animate(
            CurvedAnimation(
              parent: _menuController,
              curve: const Interval(0, 0.82, curve: Curves.easeOut),
            ),
          );
          // 淡出后仍保留当前指针的点击识别器，防止长按松手变成正文点击。
          // 完全隐藏时新手势直接交给正文，当前拖动也不会被中断。
          return IgnorePointer(
            ignoring: hidden,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {},
              onLongPress: () {},
              child: AbsorbPointer(
                absorbing: !widget.visible && !hidden,
                child: FadeTransition(opacity: fade, child: child!),
              ),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // [UI_SYNC_REFACTOR S6 修 | 2026-09-08] 顶栏置屏幕顶部（用户
            // 反馈①：此前误置于底部面板首行；对齐原版布局——← 居左，
            // 换源/刷新/缓存/更多 居右）— Qoder
            _buildTopBar(context, barColor, book, chapter, notifier),
            // 正文露出区域的按下先收起菜单，滑动同时交给正文；点击由菜单消费。
            Expanded(
              // 弹出菜单先消费外部手势；原始指针也不能传给阅读菜单与正文。
              child: AbsorbPointer(
                absorbing: _popupMenuOpen,
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (event) => _dismissFromPointer(event.pointer),
                  onPointerUp: (event) => _releaseDismissalPointer(event.pointer),
                  onPointerCancel: (event) => _releaseDismissalPointer(event.pointer),
                  onPointerSignal: (_) => notifier.hideControls(),
                  onPointerPanZoomStart: (event) =>
                      _dismissFromPointer(event.pointer),
                  onPointerPanZoomEnd: (event) =>
                      _releaseDismissalPointer(event.pointer),
                ),
              ),
            ),
            useSurfaceBlur
                ? ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                      child: _panelSurface(
                        context,
                        barColor,
                        foreground,
                        book,
                        chapter,
                        notifier,
                        state,
                        autoPageActive,
                      ),
                    ),
                  )
                : _panelSurface(
                    context,
                    barColor,
                    foreground,
                    book,
                    chapter,
                    notifier,
                    state,
                    autoPageActive,
                  ),
          ],
        ),
      ),
    );
  }

  Widget _panelSurface(
    BuildContext context,
    Color barColor,
    Color? foreground,
    Book? book,
    BookChapter? chapter,
    ReaderNotifier notifier,
    ReaderState state,
    bool autoPageActive,
  ) {
    // [PARITY A5] 面板键集对齐参考版：进度行 + 单行五键行动作行
    //（参考版菜单无亮度/字号键与亮度竖条；亮度/字号保留在读内入口
    // ReaderSettingsSheet / ReaderConfigPanel）。
    return Material(
      color: barColor,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: SafeArea(
        top: false,
        child: IconTheme(
          data: IconThemeData(color: foreground),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildProgressRow(context, notifier, state, foreground),
              _buildActionRow(context, foreground, autoPageActive),
            ],
          ),
        ),
      ),
    );
  }

  // [P2-9 | 2026-09-24] 换源流程（Fix B）：await 导航 → 路由以新 bookUrl
  // pop（发生了切换）时重载书/目录/强制刷新正文（见
  // ReaderNotifier.reloadAfterSourceChange）；用户取消（pop null）
  // 不做任何事（不重载、不提示）。
  // [SB-HUNT | 2026-09-25] 统一至 runChangeSourceFlow（与顶栏换源入口
  // 共用）：notifier 级共享重入锁（在途第二触发静默忽略）+ 必收清理
  // （clearSnackBars，离场/异常也不留残留）+ 结果去重（成功反馈只保留
  // 换源页「已切换到」，阅读器侧只弹失败条）。原 [P2-9 fix/fix2] 的
  // 无类型 pushNamed 与 10min 进行中条语义见 change_source_flow.dart。
  Future<void> _changeSourceFlow(BuildContext context, Book book) =>
      runChangeSourceFlow(ref, context, book);

  // [P2-9 | 2026-09-24] 刷新正文流程（Fix A）：强制联网抓取（绕过缓存，
  // 见 ReaderNotifier.refreshChapterContent）→ 显式成功反馈 / 失败反馈
  // 含原因（失败保留旧正文，不清空）。
  Future<void> _refreshContentFlow(BuildContext context) async {
    // [P2-9 fix2 | 2026-09-24] 与 _changeSourceFlow 同一慢路径竞态：强制
    // 抓取 > 4s（SnackBar 默认自动消失时长）时，旧写法 controller.close()
    // 踩 scaffold.dart:341 `_snackBars.first == controller` 断言 / 空队
    // 列 StateError，结果条永不出现。修法：进行中条显式 10min duration +
    // 结果就绪收起（[SB-HUNT | 2026-09-25] 改 clearSnackBars 必收，见下）
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(readerNotifierProvider.notifier);
    // [C5-hunt | 2026-09-24] 重入守卫：已有刷新在途时进行中 SnackBar 已
    // 在展示，静默返回（避免 N 次点击堆叠 N 个 SnackBar / N 次强制抓取，
    // 与换源流程 _applying 防重入同形态；notifier 侧 _refreshing 兜底）
    if (notifier.isRefreshing) return;
    messenger.showSnackBar(
      const SnackBar(
        content: Text('正在刷新正文…'),
        duration: Duration(minutes: 10),
      ),
    );
    final err = await notifier.refreshChapterContent();
    // [SB-HUNT | 2026-09-25] 必收清理（与换源流程统一）：先 clearSnackBars
    // （root 队列、空队列安全、不踩 scaffold.dart:341 断言）——抓取期间
    // 用户离场（context 已卸载）也不留进行中条；结果条仅在仍在阅读场展示
    messenger.clearSnackBars();
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(err == null ? '正文已刷新' : '刷新正文失败：$err')),
    );
  }

  // ── 分区 1：屏幕顶部工具栏（对齐原版：← 居左；⇄ ↻ ⬇ ⋮ 居右）──
  //
  // [UI_SYNC_REFACTOR S6 修 | 2026-09-08] 用户反馈②：顶栏按参考版改造——
  // 移除书名/章名胶囊（章名在正文区与页脚已有呈现），改为参考版五钮
  //（返回/换源/刷新正文/下载当前章/更多溢出）— Qoder
  Widget _buildTopBar(
    BuildContext context,
    Color barColor,
    Book? book,
    BookChapter? chapter,
    ReaderNotifier notifier,
  ) {
    // [UI_SYNC_REFACTOR S6 修 | 2026-09-08] 用户反馈②：头部信息（章节名/
    // 章节链接/书源名）应在顶栏菜单中而非正文——工具行下方补信息块
    //（章名+书源徽标 / 章节链接），对齐参考版顶栏布局 — Qoder
    // [PARITY C2 M2] 移除来源 URL 全文行：参考版顶栏信息块只保留
    // 章节名 + 书源小字徽标，不再渲染章节链接全文（来源名并入小字行）。
    final sourceName = book?.originName ?? '';
    // [P2-9 | 2026-09-24] 在线书判定（对齐顶栏 isOnline 语义，WebDAV 视作
    // 本地）：本地书（loc_book/dav:）不显示换源/刷新正文（原版 ReadMenu
    // 对本地书隐藏这两项入口）；notifier 侧守卫兜底
    // （refreshChapterContent 对本地书返回原因、不触网）
    final isOnline = book != null &&
        book.origin != BookType.localTag &&
        !book.origin.startsWith(BookType.webDavTag);
    final chapterUrl = isOnline && chapter != null && chapter.title.isNotEmpty
        ? resolveReaderChapterWebUrl(chapter)
        : null;
    final chapterTitle = Text(
      chapter?.title ?? '',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.titleSmall,
    );
    final chapterTitleWidget = chapterUrl == null
        ? chapterTitle
        : Align(
            alignment: AlignmentDirectional.centerStart,
            child: Semantics(
              link: true,
              child: Tooltip(
                message: '打开章节网页',
                child: InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: () =>
                      unawaited(openReaderChapterUrl(context, chapterUrl)),
                  child: chapterTitle,
                ),
              ),
            ),
          );
    return Material(
      color: barColor,
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Symbols.arrow_back_rounded),
                    tooltip: '退出阅读',
                    onPressed: widget.onBack,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        book?.name ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
                  // [P2-9 fix | 2026-09-24] 本地书不渲染换源/刷新正文/缓存
                  // 当前章（对齐原版 ReadMenu 本地书菜单构成：三项仅在线书
                  // 可见，与顶栏 isOnline 分支一致）。首版「isOnline ? 可点
                  // : null」的置灰形态被实机观测为「显示且点击无反应」
                  // （35% alpha no-op），现改为不渲染。
                  // 换源 = await 导航：路由 pop 新 bookUrl（发生切换）后
                  // 重载书/目录/强制刷新正文；取消（pop null）不做任何事
                  // （原实现未 await，换源后正文不刷新——缺陷根因 B）
                  // 换源闭包体保留 HEAD 基线缩进列（collection-if 后果
                  // 不重新缩进），避免 diff 引入纯空白行
                  if (isOnline) IconButton(
                    icon: const Icon(Symbols.swap_horiz_rounded),
                    tooltip: '换源',
                    onPressed: () => unawaited(_changeSourceFlow(context, book)),
                  ),
                  // [P2-9 | 2026-09-24] 刷新正文 = 强制拉取（绕过缓存，
                  // 见 ReaderNotifier.refreshChapterContent），统一 Fix A
                  // 路径 + 可见反馈（进行中/成功/失败含原因）
                  if (isOnline) IconButton(
                    icon: const Icon(Symbols.refresh_rounded),
                    tooltip: '刷新正文',
                    onPressed: () => unawaited(_refreshContentFlow(context)),
                  ),
                  // [P2-27 | 2026-09-28] 下载入口改弹「离线缓存」范围对话框
                  // （对齐原版 menu_download → showBookDownloadDialog /
                  // 参考版 DownloadSheet；默认起始 = 当前章，与原版一致），
                  // 移除自创的「直接缓存当前章」行为；共享实现见
                  // reader_download_dialog.dart（与顶栏下载钮同源）
                  if (isOnline) IconButton(
                    icon: const Icon(Symbols.download_rounded),
                    tooltip: '下载（离线缓存）',
                    onPressed: () => showReaderOfflineCacheDialog(context, ref),
                  ),
                  AppMenuButton<String>(
                    tooltip: '更多',
                    onOpen: _onPopupMenuOpen,
                    onClose: _onPopupMenuClose,
                    onSelected: (value) {
                      switch (value) {
                        case 'addBookmark':
                          widget.onAddBookmark();
                        case 'highlightRule':
                          Navigator.pushNamed(
                            context,
                            AppRoutes.highlightRules,
                          );
                        case 'replace':
                          widget.onOpenReplaceRules();
                      }
                    },
                    itemBuilder: (_) => const [
                      AppMenuItem(value: 'addBookmark', child: Text('添加书签')),
                      AppMenuItem(
                        value: 'highlightRule',
                        child: Text('高亮规则'),
                      ),
                      AppMenuItem(value: 'replace', child: Text('替换规则')),
                    ],
                  ),
                ],
              ),
            ),
            if (chapter != null || sourceName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: chapterTitleWidget,
                        ),
                        if (sourceName.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              sourceName,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── 分区：单行五键行动作行（[PARITY A5] 键集对齐参考版默认键集）──
  //
  // [PARITY A5 | 深色对齐裁决"以参考版为准"] 参考版阅读菜单默认五键：
  // 全文搜索/自动翻页/目录/朗读/设置。依据（参考源码 D:\tmp\md3_ref_legado）：
  // ① 默认开启键集 ReadButtonConfigDelegate.kt:197-203
  //   DEFAULT_ENABLED_BUTTON_IDS = {search, auto_page, catalog, read_aloud, setting}
  //   （loadButtonConfig :148-154：用户未配置时按 ReadBookButtonIds 显示序取此五键）；
  //   ② 键位定义 SystemMenuPage.kt:898-903：search→Icons.Search/search_content、
  //   auto_page→Icons.PlayArrow/auto_next_page、catalog→Icons.List/chapter_list、
  //   read_aloud→Icons.RecordVoiceOver/read_aloud、setting→Icons.Settings/setting；
  //   ③ 文案 values-zh-rCN/strings.xml：search_content=全文搜索(:1036)、
  //   auto_next_page=自动翻页(:465)、chapter_list=目录(:184)、
  //   read_aloud=朗读(:189)、setting=设置(:97)；
  //   ④ 布局 ReadBookContract.kt:359-360 readMenuIconItemsPerRow=5、
  //   readMenuIconRowCount=1（单行五键，无第二页、无字号/亮度键；亮度
  //   showBrightnessView 默认 "0" 隐藏，:390）。
  // 注：在途版曾按 MuMu 定制实例截图放 章节梗概/AI改写 占位键，但参考源码默认
  // 键集不含 ai_summary/ai_rewrite（ReadBookButtonIds 成员但默认 enabled=false，
  // ReadButtonConfigDelegate.kt:172-190 normalizeButtonConfig），故按源码移除；
  // 如需保留 AI 占位请主代理另立裁决。替换/更多入口保留于顶栏更多溢出菜单，
  // 亮度/字号保留在读内（ReaderSettingsSheet / ReaderConfigPanel）。
  Widget _buildActionRow(
    BuildContext context,
    Color? foreground,
    bool autoPageActive,
  ) {
    final cs = Theme.of(context).colorScheme;
    Widget item(
      IconData icon,
      String label,
      VoidCallback onTap, {
      bool active = false,
    }) {
      final color = active ? cs.primary : (foreground ?? cs.onSurfaceVariant);
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 24, color: color),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: color),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 键集沿用参考默认五键，按用户要求将目录移至最左，其余相对顺序不变。
    // 使用 Symbols 图标；auto_page 运行中切 pause 图标 +
    // primary 色（参考 active 态以颜色标记）。
    final items = <Widget>[
      item(Symbols.format_list_bulleted_rounded, '目录', widget.onOpenCatalog),
      item(Symbols.search_rounded, '全文搜索', widget.onOpenContentSearch),
      item(
        autoPageActive
            ? Symbols.pause_rounded
            : Symbols.play_arrow_rounded,
        '自动翻页',
        widget.onToggleAutoPage,
        active: autoPageActive,
      ),
      item(Symbols.headphones_rounded, '朗读', widget.onReadAloud),
      item(Symbols.settings_rounded, '设置', widget.onOpenSettings),
    ];
    return SizedBox(
      height: 76,
      child: Row(children: items),
    );
  }

  // ── 分区：进度滑条行（page=调章内页 / chapter=调章节）──
  Widget _buildProgressRow(
    BuildContext context,
    ReaderNotifier notifier,
    ReaderState state,
    Color? foreground,
  ) {
    final chapterPageCount = notifier.paginator.pageCountForChapter(
      state.currentChapterIndex,
    );
    final usePageSeek =
        widget.progressBehavior == 'page' &&
        chapterPageCount > 1 &&
        widget.onSeekPage != null;
    final currentPage = state.currentChapterPos.clamp(
      0,
      chapterPageCount > 0 ? chapterPageCount - 1 : 0,
    );
    final cs = Theme.of(context).colorScheme;
    final progressColor = foreground ?? cs.onSurface;
    final accentColor = foreground ?? cs.primary;
    final sliderTheme = SliderTheme.of(context).copyWith(
      trackHeight: 4,
      showValueIndicator: ShowValueIndicator.never,
      trackShape: const RoundedRectSliderTrackShape(),
      thumbShape: const RoundSliderThumbShape(
        enabledThumbRadius: 7,
        disabledThumbRadius: 6,
        elevation: 0,
        pressedElevation: 0,
      ),
      thumbColor: accentColor,
      activeTrackColor: accentColor,
      inactiveTrackColor: progressColor.withValues(alpha: 0.12),
      disabledThumbColor: progressColor.withValues(alpha: 0.38),
      disabledActiveTrackColor: progressColor.withValues(alpha: 0.15),
      disabledInactiveTrackColor: progressColor.withValues(alpha: 0.08),
      tickMarkShape: SliderTickMarkShape.noTickMark,
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
      overlayColor: accentColor.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 12),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            tooltip: '上一章',
            color: progressColor,
            disabledColor: progressColor.withValues(alpha: 0.38),
            onPressed: state.hasPreviousChapter && !state.isLoading
                ? () => unawaited(notifier.prevChapter())
                : null,
            icon: const Icon(Icons.skip_previous_rounded),
          ),
          Expanded(
            child: SliderTheme(
              data: sliderTheme,
              child: usePageSeek
                  ? Slider(
                      value: currentPage.toDouble(),
                      min: 0,
                      max: (chapterPageCount - 1).toDouble(),
                      divisions: chapterPageCount - 1,
                      onChanged: (value) => widget.onSeekPage!(value.toInt()),
                    )
                  : Slider(
                      value: state.chapters.isNotEmpty
                          ? state.currentChapterIndex.toDouble()
                          : 0,
                      min: 0,
                      max: state.chapters.length > 1
                          ? (state.chapters.length - 1).toDouble()
                          : 1,
                      divisions: state.chapters.length > 1
                          ? state.chapters.length - 1
                          : null,
                      onChanged: state.chapters.length > 1
                          ? (value) => notifier.goToChapter(value.toInt())
                          : null,
                    ),
            ),
          ),
          IconButton(
            tooltip: '下一章',
            color: progressColor,
            disabledColor: progressColor.withValues(alpha: 0.38),
            onPressed: state.hasNextChapter && !state.isLoading
                ? () => unawaited(notifier.nextChapter())
                : null,
            icon: const Icon(Icons.skip_next_rounded),
          ),
        ],
      ),
    );
  }
}
