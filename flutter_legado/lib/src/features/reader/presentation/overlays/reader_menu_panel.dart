import '../../../../theme/app_surface_material.dart';
import '../../../../widgets/app_glass_surface.dart';
import '../../../../app/routing/route_names.dart';
import '../../../../app/bootstrap/application_dependencies.dart';
import '../../../../providers/chapter_content_provider.dart';
import '../../../../domain/models/source_action_result.dart';
import '../../application/reader_settings_provider.dart';
import '../../../../l10n/app_localization.dart';
import '../../../../widgets/app_menu.dart';
import '../../../../theme/app_motion.dart';

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import 'package:flutter/services.dart';

import '../../../../models/models.dart';
import '../../../book_sources/book_sources.dart';
import '../../../../providers/sync/sync_notifier.dart';
import '../../../../utils/source_login_entry.dart';
import '../../../book_sources/presentation/webview_login_screen.dart';
import '../../../../widgets/help/help_assets.dart';
import '../../../../widgets/help/show_help.dart';
import '../../../../widgets/reader/change_chapter_source_sheet.dart';
import 'reader_brightness_control.dart';
import 'reader_menu_controls.dart';
import '../../application/reader_notifier.dart';
import '../../../../providers/ui_settings/ui_settings_notifier.dart';

import '../../../../widgets/reader/change_source_flow.dart';
import '../../../../widgets/reader/reader_chapter_link.dart';
import 'reader_download_dialog.dart';
import 'reader_content_edit_dialog.dart';

part 'reader_menu_actions.part.dart';

/// 阅读器悬浮菜单，进度与操作分层，保留正文手势及现有业务回调。— Codex + UI
///
/// 结构：屏幕顶栏（返回/书名/换源/刷新正文/下载（离线缓存）/更多溢出 +
/// 章节信息块）→ 底部进度面板 + 单行五键操作栏。
/// 底部按钮按用户指定顺序排列：目录/全文搜索/自动翻页/朗读/设置。
/// 键集沿用参考 ReadButtonConfigDelegate.kt:197-203（
/// DEFAULT_ENABLED_BUTTON_IDS = search/auto_page/catalog/read_aloud/setting，
/// 显示顺序沿用已确认的五键，不增加第二页。
/// 亮度控件按配置显示横向底栏或纵向侧栏，默认关闭。
/// 常挂载+双向动画（visible 驱动）。
class ReaderMenuPanel extends ConsumerStatefulWidget {
  final bool visible;
  final Widget? bottomAccessory;
  final VoidCallback onBack;
  final VoidCallback onAddBookmark;
  final VoidCallback onOpenCatalog;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenContentSearch;
  final VoidCallback onReadAloud;
  final VoidCallback onToggleAutoPage;
  final VoidCallback onOpenReplaceRules;
  final String progressBehavior;
  final ValueChanged<int>? onSeekPage;

  const ReaderMenuPanel({
    super.key,
    required this.visible,
    this.bottomAccessory,
    required this.onBack,
    required this.onAddBookmark,
    required this.onOpenCatalog,
    required this.onOpenSettings,
    required this.onOpenContentSearch,
    required this.onReadAloud,
    required this.onToggleAutoPage,
    required this.onOpenReplaceRules,
    this.progressBehavior = 'chapter',
    this.onSeekPage,
  });

  @override
  ConsumerState<ReaderMenuPanel> createState() => _ReaderMenuPanelState();
}

class _ReaderMenuPanelState extends ConsumerState<ReaderMenuPanel>
    with SingleTickerProviderStateMixin, _ReaderMenuActions {
  final Set<int> _dismissalPointers = {};
  bool _popupMenuOpen = false;

  void _onPopupMenuOpen() {
    setState(() => _popupMenuOpen = true);
    unawaited(_refreshMenuFlags());
  }

  @override
  void initState() {
    super.initState();
    unawaited(
      Future.microtask(() {
        if (mounted) {
          return ref.read(syncNotifierProvider.notifier).loadConfig();
        }
      }).catchError((Object _) {
        // 预加载失败交由实际同步操作重试，不记录可能含凭据的平台错误。
        debugPrint('WebDAV 配置预加载失败，将在使用时重试');
      }),
    );
  }

  void _onPopupMenuClose() => setState(() => _popupMenuOpen = false);

  void _dismissFromPointer(int pointer) {
    setState(() => _dismissalPointers.add(pointer));
    ref.read(readerNotifierProvider.notifier).hideControls();
  }

  void _releaseDismissalPointer(int pointer) {
    if (_dismissalPointers.remove(pointer)) setState(() {});
  }

  Widget _dismissalRegion(ReaderNotifier notifier) => AbsorbPointer(
    absorbing: _popupMenuOpen,
    child: Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) => _dismissFromPointer(event.pointer),
      onPointerUp: (event) => _releaseDismissalPointer(event.pointer),
      onPointerCancel: (event) => _releaseDismissalPointer(event.pointer),
      onPointerSignal: (_) => notifier.hideControls(),
      onPointerPanZoomStart: (event) => _dismissFromPointer(event.pointer),
      onPointerPanZoomEnd: (event) => _releaseDismissalPointer(event.pointer),
    ),
  );

  // 进出场：进 220（fadeIn180 内含）/ 出 180（对齐参考 0.88 缩放族）
  late final AnimationController _menuController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    reverseDuration: const Duration(milliseconds: 180),
    value: widget.visible ? 1 : 0,
  );

  late final CurvedAnimation _menuSlideCurve = CurvedAnimation(
    parent: _menuController,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  late final CurvedAnimation _menuFadeCurve = CurvedAnimation(
    parent: _menuController,
    curve: const Interval(0, 0.82, curve: Curves.easeOut),
  );

  void _syncMotion() {
    if (AppMotion.reduced(context)) {
      _menuController.value = widget.visible ? 1 : 0;
    } else {
      widget.visible ? _menuController.forward() : _menuController.reverse();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didUpdateWidget(covariant ReaderMenuPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible != widget.visible) {
      if (!widget.visible) {
        _popupMenuOpen = false;
        _sourceActionMenuController.close();
      }
      _syncMotion();
    }
  }

  @override
  void dispose() {
    _menuFadeCurve.dispose();
    _menuSlideCurve.dispose();
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
    ref.watch(readerSettingsProvider);
    final settings = ref.read(readerSettingsRepositoryProvider).current;
    final brightnessControl = settings.brightnessControl;
    final autoPageActive = settings.autoPageTurn.enabled;
    final foreground = settings.menuTheme.mode == 2 ? cs.primary : cs.onSurface;
    final barColor = cs.surfaceContainerHigh;
    // 毛玻璃只改变表面的透明度和模糊，不改变菜单配色来源。
    final ui = ref.watch(uiSettingsProvider);
    final topMaterial = AppSurfaceMaterial.topBar(
      color: barColor,
      settings: ui,
      liquidGlass: true,
    );
    final bottomMaterial = AppSurfaceMaterial.bottomBar(
      color: barColor,
      settings: ui,
      liquidGlass: true,
    );

    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _menuController,
        builder: (context, child) {
          final v = _menuController.value;
          final hidden = v == 0 && !widget.visible;
          if (hidden && _dismissalPointers.isEmpty) {
            return const SizedBox.shrink();
          }
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
                child: FadeTransition(opacity: _menuFadeCurve, child: child!),
              ),
            ),
          );
        },
        child: ReaderMenuControlTheme(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // [UI_SYNC_REFACTOR S6 修 | 2026-09-08] 顶栏置屏幕顶部（用户
              // 反馈①：此前误置于底部面板首行；对齐原版布局——← 居左，
              // 换源/刷新/缓存/更多 居右）— Qoder
              SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -1),
                  end: Offset.zero,
                ).animate(_menuSlideCurve),
                child: _buildTopBar(context, book, chapter, topMaterial),
              ),
              // 正文露出区域的按下先收起菜单，滑动同时交给正文；点击由菜单消费。
              Expanded(
                // 弹出菜单先消费外部手势；原始指针也不能传给阅读菜单与正文。
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _dismissalRegion(notifier),
                    if (brightnessControl.mode == 2)
                      Align(
                        alignment: brightnessControl.onLeft
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: Offset(brightnessControl.onLeft ? -1 : 1, 0),
                            end: Offset.zero,
                          ).animate(_menuSlideCurve),
                          child: SafeArea(
                            top: false,
                            bottom: false,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              child: SizedBox(
                                width: ReaderBrightnessControl.verticalWidth,
                                height: 240,
                                child: AppGlassSurface(
                                  material: bottomMaterial,
                                  visibility: _menuFadeCurve,
                                  topRadius:
                                      ReaderBrightnessControl.verticalWidth / 2,
                                  bottomRadius:
                                      ReaderBrightnessControl.verticalWidth / 2,
                                  child: Material(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(
                                      ReaderBrightnessControl.verticalWidth / 2,
                                    ),
                                    child: ReaderBrightnessControl(
                                      compact: true,
                                      vertical: true,
                                      onSwitchSide: _switchBrightnessSide,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(_menuSlideCurve),
                child: Stack(
                  children: [
                    // 悬浮面板外侧留白属于正文露出区，沿用菜单外手势规则。
                    Positioned.fill(child: _dismissalRegion(notifier)),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (widget.bottomAccessory != null)
                              widget.bottomAccessory!,
                            AppGlassSurface(
                              key: const ValueKey('reader-progress-surface'),
                              material: bottomMaterial,
                              visibility: _menuFadeCurve,
                              topRadius: 28,
                              bottomRadius: 28,
                              child: _buildProgressPanel(
                                context,
                                foreground,
                                notifier,
                                state,
                              ),
                            ),
                            const SizedBox(height: 10),
                            AppGlassSurface(
                              key: const ValueKey('reader-actions-surface'),
                              material: bottomMaterial,
                              visibility: _menuFadeCurve,
                              topRadius: 28,
                              bottomRadius: 28,
                              child: Material(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(28),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 6,
                                  ),
                                  child: _buildActionRow(
                                    context,
                                    foreground,
                                    autoPageActive,
                                  ),
                                ),
                              ),
                            ),
                          ],
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
    );
  }

  Widget _buildProgressPanel(
    BuildContext context,
    Color? foreground,
    ReaderNotifier notifier,
    ReaderState state,
  ) {
    // 亮度横条位于章节进度上方；悬浮面板外侧统一计算留白与系统安全区。
    final brightnessControl = ref
        .read(readerSettingsRepositoryProvider)
        .current
        .brightnessControl;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(28),
      child: IconTheme(
        data: IconThemeData(color: foreground),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (brightnessControl.mode == 1)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: ReaderBrightnessControl(compact: true),
              ),
            _buildProgressRow(context, notifier, state, foreground),
          ],
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
      const SnackBar(content: Text('正在刷新正文…'), duration: Duration(minutes: 10)),
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

  // 顶栏返回按钮独立，右侧动作共用表面；标题和章节链接保留原回调。
  Widget _buildTopBar(
    BuildContext context,
    Book? book,
    BookChapter? chapter,
    AppSurfaceMaterial material,
  ) {
    final theme = Theme.of(context);
    final config = ref.read(readerSettingsRepositoryProvider).current.menuTheme;
    final customText = theme.brightness == Brightness.dark
        ? config.textColorNight
        : config.textColor;
    final titleColor = customText == 0
        ? theme.colorScheme.onSurface
        : Color(customText);
    final sourceName = book?.originName ?? '';
    // [P2-9 | 2026-09-24] 在线书判定（对齐顶栏 isOnline 语义，WebDAV 视作
    // 本地）：本地书（loc_book/dav:）不显示换源/刷新正文（原版 ReadMenu
    // 对本地书隐藏这两项入口）；notifier 侧守卫兜底
    // （refreshChapterContent 对本地书返回原因、不触网）
    final isOnline =
        book != null &&
        book.origin != BookType.localTag &&
        !book.origin.startsWith(BookType.webDavTag);
    final chapterUrl = isOnline && chapter != null && chapter.title.isNotEmpty
        ? resolveReaderChapterWebUrl(chapter)
        : null;
    final chapterTitle = Text(
      chapter?.title ?? '',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.titleSmall?.copyWith(color: titleColor),
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
                  onLongPress: () =>
                      unawaited(_showChapterUrlMenu(context, chapterUrl)),
                  child: chapterTitle,
                ),
              ),
            ),
          );
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        bottom: false,
        minimum: EdgeInsets.only(top: MediaQuery.viewPaddingOf(context).top),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  ReaderMenuControlButton(
                    standalone: true,
                    icon: Symbols.arrow_back_rounded,
                    label: '退出阅读',
                    color: titleColor,
                    onPressed: widget.onBack,
                  ),
                  const Spacer(),
                  AppGlassSurface(
                    material: material,
                    visibility: _menuFadeCurve,
                    topRadius: 24,
                    bottomRadius: 24,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 本地书沿用原规则，不显示换源、刷新和下载。
                        if (isOnline) ...[
                          ReaderMenuControlButton(
                            icon: Symbols.swap_horiz_rounded,
                            label: '换源',
                            color: titleColor,
                            onPressed: () =>
                                _showChangeSourceMenu(context, book),
                          ),
                          ReaderMenuControlButton(
                            icon: Symbols.refresh_rounded,
                            label: '刷新正文',
                            color: titleColor,
                            onPressed: () =>
                                unawaited(_refreshContentFlow(context)),
                          ),
                          ReaderMenuControlButton(
                            icon: Symbols.download_rounded,
                            label: '下载（离线缓存）',
                            color: titleColor,
                            onPressed: () =>
                                showReaderOfflineCacheDialog(context, ref),
                          ),
                        ],
                        // 保留菜单节点及控制器，切换材质不关闭已展开的菜单。
                        AppMenuAnchor<String>(
                          onOpen: _onPopupMenuOpen,
                          onClose: _onPopupMenuClose,
                          onSelected: _handleMenuAction,
                          itemBuilder: (_) => _menuItems(book, isOnline),
                          builder: (context, controller, _) =>
                              ReaderMenuControlButton(
                                icon: Symbols.more_vert_rounded,
                                label: '更多',
                                color: titleColor,
                                onPressed: () => controller.isOpen
                                    ? controller.close()
                                    : controller.open(),
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (book != null || chapter != null || sourceName.isNotEmpty) ...[
                const SizedBox(height: 8),
                AppGlassSurface(
                  material: material,
                  visibility: _menuFadeCurve,
                  topRadius: 16,
                  bottomRadius: 16,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                book?.name ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: titleColor,
                                ),
                              ),
                              if (chapter != null) ...[
                                const SizedBox(height: 4),
                                chapterTitleWidget,
                              ],
                            ],
                          ),
                        ),
                        if (sourceName.isNotEmpty)
                          Flexible(
                            child: Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: isOnline
                                  ? AppMenuAnchor<String>(
                                      controller: _sourceActionMenuController,
                                      onOpen: () =>
                                          setState(() => _popupMenuOpen = true),
                                      onClose: _onPopupMenuClose,
                                      itemBuilder: (_) =>
                                          _sourceActionMenuItems(book),
                                      onSelected: (value) => unawaited(
                                        _handleSourceAction(
                                          context,
                                          book,
                                          value,
                                        ),
                                      ),
                                      builder: (context, controller, _) =>
                                          InkWell(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            onTap: () => unawaited(
                                              _showSourceMenu(context, book),
                                            ),
                                            child: _sourceBadge(
                                              context,
                                              sourceName,
                                            ),
                                          ),
                                    )
                                  : _sourceBadge(context, sourceName),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _sourceBadge(BuildContext context, String name) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primary,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 12,
        color: Theme.of(context).colorScheme.onPrimary,
      ),
    ),
  );

  Future<void> _switchBrightnessSide() async {
    final repository = ref.read(readerSettingsRepositoryProvider);
    try {
      await repository.updateBrightnessControl(
        onLeft: !repository.current.brightnessControl.onLeft,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('亮度控件设置保存失败，请重试')));
    }
  }

  // 保留已确认的五个操作及顺序，材质与触控统一由阅读器组件适配。
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
        child: ReaderMenuControlButton(
          icon: icon,
          label: label,
          onPressed: onTap,
          color: color,
          showLabel: true,
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
        autoPageActive ? Symbols.pause_rounded : Symbols.play_arrow_rounded,
        '自动翻页',
        widget.onToggleAutoPage,
        active: autoPageActive,
      ),
      item(Symbols.headphones_rounded, '朗读', widget.onReadAloud),
      item(Symbols.settings_rounded, '设置', widget.onOpenSettings),
    ];
    return Row(children: items);
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
    final progressColor = foreground ?? Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          ReaderMenuControlButton(
            label: '上一章',
            color: progressColor,
            onPressed: state.hasPreviousChapter && !state.isLoading
                ? () => unawaited(notifier.prevChapter())
                : null,
            icon: Icons.skip_previous_rounded,
          ),
          Expanded(
            child: ReaderMenuProgressSlider(
              label: usePageSeek ? '章内页码' : '章节进度',
              color: progressColor,
              value: usePageSeek
                  ? currentPage.toDouble()
                  : state.chapters.isNotEmpty
                  ? state.currentChapterIndex.toDouble()
                  : 0,
              max: usePageSeek
                  ? (chapterPageCount - 1).toDouble()
                  : state.chapters.length > 1
                  ? (state.chapters.length - 1).toDouble()
                  : 1,
              divisions: usePageSeek
                  ? chapterPageCount - 1
                  : state.chapters.length > 1
                  ? state.chapters.length - 1
                  : null,
              onChanged: usePageSeek
                  ? (value) => widget.onSeekPage!(value.toInt())
                  : state.chapters.length > 1
                  ? (value) => notifier.goToChapter(value.toInt())
                  : null,
            ),
          ),
          ReaderMenuControlButton(
            label: '下一章',
            color: progressColor,
            onPressed: state.hasNextChapter && !state.isLoading
                ? () => unawaited(notifier.nextChapter())
                : null,
            icon: Icons.skip_next_rounded,
          ),
        ],
      ),
    );
  }
}
