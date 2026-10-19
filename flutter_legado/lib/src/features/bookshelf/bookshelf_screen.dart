import '../../widgets/app_content_transition.dart';
import 'application/bookshelf_import_controller.dart';
import 'application/bookshelf_import_provider.dart';
import '../../utils/error_message.dart';

import '../book_detail/book_detail_notifier.dart';

import '../../providers/reading_provider.dart';
import '../privacy/privacy_gate.dart';
import '../../widgets/app_menu.dart';
import '../../widgets/book_cover.dart';

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../widgets/legado_app_bar.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:share_plus/share_plus.dart';

import '../../l10n/app_localization.dart';
import '../../models/models.dart';
import 'bookshelf_notifier.dart';
import '../reader/application/reader_notifier.dart';
import '../../app/routing/route_names.dart';
import '../../services/local_book_store.dart';
import '../../utils/book_open_utils.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_bottom_bar_inset.dart';
import '../../widgets/app_progress_indicator.dart';
import 'widgets/book_grid_item.dart';
import 'widgets/book_list_item.dart';
import 'widgets/bookshelf_group_label.dart';
import '../../widgets/custom_refresh_indicator.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/skeleton.dart'; // [LAYOUT_PLAN P4] 首屏 Skeleton 接线

/// 书架页面（Riverpod ConsumerStatefulWidget）
///
/// 状态由 [BookshelfNotifier] 管理，Widget 层仅负责渲染与交互。
/// Notifier 在 build() 时自动加载数据，无需 initState。
/// [骨架对齐 2.0.260 | 台账 1-3] 布局骨架（对齐参考 03/03b 截图）：
/// 可折叠大标题「书架」→ 常驻分组 tab 行（无分组数据时回落单一「全部」
/// tab）→ 3 列大封面网格（卡片=封面+居中书名，[parity fix 2.0.264] 列数
/// 2→3 修正）。搜索入口收敛为顶栏
/// 🔍 图标；页内全宽搜索条与统计/最近阅读行已按红线清理移除。
class BookshelfScreen extends ConsumerStatefulWidget {
  /// 回滚顶部信号（主页双击底栏书架项时自增，对标原版 gotoTop）
  final ValueNotifier<int>? scrollTopSignal;

  const BookshelfScreen({super.key, this.scrollTopSignal});

  @override
  ConsumerState<BookshelfScreen> createState() => _BookshelfScreenState();
}

// [骨架对齐 2.0.260 | 台账 1-3] 分组数变化时 _ensureTabController 会重建
// TabController（生命周期内多个 ticker），故用 TickerProviderStateMixin
// 而非 SingleTickerProviderStateMixin（后者对第二个 ticker 抛断言）
class _BookshelfScreenState extends ConsumerState<BookshelfScreen>
    with TickerProviderStateMixin {
  TabController? _tabController;
  int _tabControllerLen = 0;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.scrollTopSignal?.addListener(_onScrollTopSignal);
  }

  @override
  void dispose() {
    widget.scrollTopSignal?.removeListener(_onScrollTopSignal);
    _scrollController.dispose();
    _tabController?.removeListener(_onTabControllerChanged);
    _tabController?.dispose();
    super.dispose();
  }

  /// 双击底栏书架项 → 列表回滚顶部（对标 BaseBookshelfFragment.gotoTop）
  void _onScrollTopSignal() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  /// 按分组数量维护 TabController（分组数变化时重建）。
  /// 不在 build 期间同步 index（会被 TabBar 内部状态覆盖），
  /// 改由 [_onTabControllerChanged] 在帧后回调中对齐。
  TabController _ensureTabController(int length) {
    if (_tabController == null || _tabControllerLen != length) {
      _tabController?.removeListener(_onTabControllerChanged);
      _tabController?.dispose();
      _tabController = TabController(length: length, vsync: this);
      _tabController!.addListener(_onTabControllerChanged);
      _tabControllerLen = length;
    }
    return _tabController!;
  }

  /// TabController 变化 → 持久化选中分组（对标原版 onTabSelected）
  void _onTabControllerChanged() {
    final controller = _tabController;
    if (controller == null || controller.indexIsChanging) return;
    final state = ref.read(bookshelfNotifierProvider);
    if (controller.index != state.selectedGroupIndex) {
      _saveDisplaySettings(
        () => ref
            .read(bookshelfNotifierProvider.notifier)
            .selectGroup(controller.index),
      );
    }
  }

  /// 保存失败后提示，偏好状态由共享仓储回退。
  Future<void> _saveDisplaySettings(Future<void> Function() save) async {
    try {
      await save();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.loginSaveFailed)));
      }
    }
  }

  /// 状态选中分组 → 帧后同步到 TabController（避免 build 期间改动）
  void _syncTabControllerIndex(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = _tabController;
      if (!mounted || controller == null) return;
      if (controller.index != index && index < controller.length) {
        controller.animateTo(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bookshelfNotifierProvider);
    // [骨架对齐 2.0.260 | 台账 1-3] 主内容/空态：大标题 + 分组 tab 行以
    // sliver 形式并入下方 CustomScrollView（对齐参考 03/03b 截图：空态
    // 同样保留「书架」大标题 + 分组 tab 行）；加载/错误态保留标准
    // LegadoAppBar。
    final plainAppBar =
        (state.isLoading && state.books.isEmpty) ||
        (state.error != null && state.books.isEmpty);
    // [GLOBALCOMP B4] 页壳统一：AppScaffold（行为等价直通 Scaffold）
    return AppScaffold(
      topBar: plainAppBar ? _buildAppBar(context, ref) : null,
      body: PrivacyGroupGate(
        group: ref.watch(bookshelfNotifierProvider).selectedGroup,
        lockedBuilder: (context, locked) => CustomScrollView(
          slivers: [
            _buildHeaderSliver(
              context,
              ref,
              state.copyWith(isBatchMode: false),
            ),
            SliverFillRemaining(
              child: Padding(
                padding: EdgeInsets.only(bottom: AppBottomBarInset.of(context)),
                child: locked,
              ),
            ),
          ],
        ),
        child: _buildBody(context, ref),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bookshelfNotifierProvider);
    return LegadoAppBar(
      // [骨架对齐 2.0.260 | 台账 1-3] 分组 tab 行常驻于 sliver 头部
      // （含空态）；标准栏（加载/错误态）仅显示「书架」大标题
      title: Text(
        context.l10n.bookshelf,
        style: Theme.of(context).textTheme.headlineMedium
            ?.copyWith(fontSize: 28),
      ),
      // [UI-fix 2.0.258] 选择模式下加载态/错误态顶栏同样切换为批量动作集
      actions: _animatedActions(context, state),
    );
  }

  List<Widget> _animatedActions(BuildContext context, BookshelfState state) => [
    AppActionTransition(
      identity: state.isBatchMode,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: state.isBatchMode
            ? _buildBatchAppBarActions(context, ref)
            : _buildAppBarActions(context, ref),
      ),
    ),
  ];

  /// [UI-fix 2.0.258] 选择模式顶栏动作集（全选/反选/删除/取消，对标原版
  /// selectMode 顶栏切换语义）：进入选择模式后顶栏由「搜索+溢出菜单」
  /// 切换为批量操作；tooltip 会暴露为 Android 无障碍 content-desc，
  /// 保证 uiautomator dump 可检索到 全选/反选/删除/取消 关键词。
  List<Widget> _buildBatchAppBarActions(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(bookshelfNotifierProvider.notifier);
    return [
      IconButton(
        icon: const Icon(Icons.select_all),
        tooltip: context.l10n.selectAll,
        onPressed: notifier.selectAll,
      ),
      IconButton(
        icon: const Icon(Icons.flip_rounded),
        tooltip: context.l10n.invertSelection,
        onPressed: notifier.invertSelection,
      ),
      IconButton(
        icon: const Icon(Icons.delete_rounded),
        tooltip: context.l10n.delete,
        onPressed: () => _confirmDeleteSelected(context, ref),
      ),
      IconButton(
        icon: const Icon(Icons.close_rounded),
        tooltip: context.l10n.cancel,
        onPressed: notifier.toggleBatchMode,
      ),
    ];
  }

  /// [UI-fix 2.0.258] 选择模式删除确认（对齐原版批量删除前二次确认，
  /// 防误删；确认后逐本删除并退出选择模式）
  Future<void> _confirmDeleteSelected(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final state = ref.read(bookshelfNotifierProvider);
    final count = state.selectedUrls.length;
    if (count == 0) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.deleteBook),
        content: Text(context.l10n.confirmDeleteSelectedBooks(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(bookshelfNotifierProvider.notifier).deleteSelectedBooks();
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(context.l10n.deletedBookCount(count))),
      );
  }

  /// 分组 TabBar（对标原版 BookshelfFragment1：可滚动 TabLayout）
  ///
  /// [骨架对齐 2.0.260 | 台账 1-3] tab 行常驻：数据未就绪（groups 为空，
  /// 如加载失败）时回落单一「全部」tab（对标参考空态截图 03）；
  /// 选中态与切换经 [BookshelfNotifier.selectGroup] 持久化并真正过滤列表
  /// （[BookshelfStateGrouping.currentGroupBooks]）。
  Widget _buildGroupTabBar(BuildContext context, BookshelfState state) {
    final groups = state.groups.isNotEmpty
        ? state.groups
        : [
            BookGroup(
              groupId: BookGroupId.all,
              groupName: context.l10n.allBooks,
            ),
          ];
    final controller = _ensureTabController(groups.length);
    _syncTabControllerIndex(
      state.selectedGroupIndex.clamp(0, groups.length - 1),
    );
    final colorScheme = Theme.of(context).colorScheme;
    // [LAYOUT_MOTION_AUDIT L3] Tab 文案走 labelLargeEmphasized（M3 labelLarge + Medium 强调）
    final labelStyle = Theme.of(context).textTheme.labelLarge
        ?.copyWith(fontWeight: FontWeight.w500);
    // [parity C3 B1] 分组 tab 单组左对齐：根因——SliverAppBar.large 的 bottom 槽
    // 以「松约束」下发，M3 可滚动 TabBar 在松约束下收缩为内容宽度并被父级
    // 居中（单组「全部」时整行偏右，多组时首 tab 同样不贴左）。包一层
    // SizedBox(width: double.infinity) 把 TabBar 撑满 bottom 槽宽度后，
    // isScrollable + TabAlignment.start 才能真正把首 tab 钉在左缘。
    // 注意：不能用 SizedBox.expand（高度被放大到 bottom 槽全高，tab 行爆高）。
    return SizedBox(
      width: double.infinity,
      child: TabBar(
        controller: controller,
        isScrollable: true, // 原版 tabMode = MODE_SCROLLABLE
        tabAlignment: TabAlignment.start,
        // [parity fix 2.0.264 补修 | 台账 1-3] tab 行左缘 20dp：参考 03b 首
        // tab 墨迹 x≈59px@3x≈20dp（复审量测），此前 edgePadding 0 钉屏左缘
        // （实测 x≈2px）贴死；可滚动 TabBar 下 padding 仅作用于首尾两 tab
        // 边缘，故只加 left 不影响尾 tab
        padding: const EdgeInsets.only(left: 20),
        // [LAYOUT_MOTION_AUDIT L3] minTabWidth 0（Flutter 侧等价 labelPadding 置零）
        labelPadding: EdgeInsets.zero,
        // [LAYOUT_MOTION_AUDIT L3] 无分割线
        dividerColor: Colors.transparent,
        // [LAYOUT_MOTION_AUDIT L3] 无分割线
        dividerHeight: 0,
        // [LAYOUT_MOTION_AUDIT L3] 选中走 primary
        labelColor: colorScheme.primary,
        // [LAYOUT_MOTION_AUDIT L3] 未选中走 onSurfaceVariant
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        // [LAYOUT_MOTION_AUDIT L3] labelLargeEmphasized
        labelStyle: labelStyle,
        // [LAYOUT_MOTION_AUDIT L3] labelLargeEmphasized
        unselectedLabelStyle: labelStyle,
        // [MD3 Batch 2] 前景走全局 tabBarTheme（onSurface/onSurfaceVariant +
        // primary 指示器），与 M3 AppBar surface 背景配对，不再硬编码白色
        // [骨架对齐 2.0.260] 选中 tab = primary 字色 + 短下划线（对齐参考 03b）
        tabs: groups
            .map((g) => Tab(text: bookshelfGroupLabel(context, g)))
            .toList(),
      ),
    );
  }

  List<Widget> _buildAppBarActions(BuildContext context, WidgetRef ref) {
    return [
      // [UI-fix v2.0.175] 恢复搜索图标（原版 main_bookshelf.xml actionbar
      // 自带搜索项，红线对齐；Dynamic 搜索行双入口并存——用户报障找不到搜索）
      IconButton(
        icon: const Icon(Symbols.search_rounded),
        tooltip: context.l10n.search,
        onPressed: () => Navigator.pushNamed(context, AppRoutes.search),
      ),
      // 原版 main_bookshelf.xml 无常驻视图切换按钮，网格/列表切换在溢出菜单「布局设置」
      AppMenuButton<String>(
        tooltip: context.l10n.more,
        itemBuilder: (_) => _buildShelfMenuItems(),
        onSelected: (action) => _handleMenuAction(context, ref, action),
      ),
    ];
  }

  List<AppMenuEntry<String>> _buildShelfMenuItems() {
    AppMenuItem<String> item(String action, String label, IconData icon) =>
        AppMenuItem(value: action, leadingIcon: Icon(icon), child: Text(label));
    return [
      item('remote', context.l10n.remoteBooks, Symbols.wifi_rounded),
      item('import', context.l10n.addLocalBook, Symbols.save_rounded),
      item('update_all', context.l10n.updateAll, Symbols.refresh_rounded),
      item('layout', context.l10n.layoutSettings, Symbols.grid_view_rounded),
      item(
        'groups',
        context.l10n.groupManagement,
        Symbols.view_carousel_rounded,
      ),
      item('add_url', context.l10n.addBookUrl, Symbols.link_rounded),
      item('select_mode', context.l10n.selectionMode, Symbols.edit_rounded),
      item('manage', context.l10n.manageBookshelf, Symbols.bookmarks_rounded),
      item(
        'offline_cache',
        context.l10n.offlineCache,
        Symbols.download_for_offline_rounded,
      ),
      item(
        'export_list',
        context.l10n.exportBookList,
        Symbols.upload_file_rounded,
      ),
      item(
        'import_list',
        context.l10n.importBookList,
        Symbols.cloud_download_rounded,
      ),
      item('log', context.l10n.logs, Symbols.history_rounded),
    ];
  }

  Widget _buildBody(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bookshelfNotifierProvider);

    if (state.isLoading && state.books.isEmpty) {
      // [LAYOUT_PLAN P4] 首屏 Skeleton 接线：按当前视图模式渲染网格/列表骨架
      // （shimmer 1200ms 已在 skeleton.dart 实现），替代整页 LoadingIndicator
      if (state.isGridView) {
        // 骨架与当前网格列数保持一致，封面按实际宽度保留 5:7 比例。
        return LayoutBuilder(
          builder: (context, constraints) {
            return GridView.builder(
              padding: AppBottomBarInset.padding(
                context,
                const EdgeInsets.fromLTRB(22, 8, 22, 8),
              ),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: state.gridColumns,
                mainAxisSpacing: 20,
                crossAxisSpacing: 20,
                childAspectRatio: _bookshelfGridCellAspectRatio(
                  constraints.maxWidth - 44,
                  state.gridColumns,
                ),
              ),
              itemCount: state.gridColumns * 2,
              itemBuilder: (_, _) => const GridSkeletonItem(),
            );
          },
        );
      }
      return ListView.builder(
        padding: AppBottomBarInset.padding(
          context,
          const EdgeInsets.symmetric(vertical: 8),
        ),
        itemCount: 8,
        itemBuilder: (_, _) => const ListSkeletonItem(),
      );
    }

    if (state.error != null && state.books.isEmpty) {
      return ErrorView(
        message: state.error!,
        onRetry: () => ref.read(bookshelfNotifierProvider.notifier).refresh(),
      );
    }

    if (state.isEmpty) {
      // [骨架对齐 2.0.260 | 台账 1-3] 空态对齐参考 03 截图：大标题「书架」
      // + 分组 tab 行常驻，正文区居中颜文字彩蛋（kaomoji 模式为 2026-08-29
      // 用户授权彩蛋，点击换颜文字）
      return CustomScrollView(
        slivers: [
          _buildHeaderSliver(context, ref, state),
          SliverFillRemaining(
            hasScrollBody: false,
            child: state.isBatchMode
                // [UI-fix 2.0.258] 选择模式 + 空书架（对齐参考版 05 截图：
                // 空态上方仍呈现「已选0本 · 共0本」胶囊）
                ? Column(
                    children: [
                      _buildBatchSummaryCard(context, ref, state),
                      Expanded(
                        child: EmptyState(
                          icon: Symbols.library_books_rounded,
                          title: context.l10n.emptyBookshelf,
                          kaomoji: true,
                        ),
                      ),
                    ],
                  )
                // [骨架对齐 2.0.260 | 台账 1-3] 溢出防护：剩余区高度不足
                // （展开 LargeTitle≈152 + tab 行 56 后，矮视口仅剩 ~90px）时
                // 颜文字列（自然高 ~106px）会 RenderFlex overflow。经
                // FittedBox(scaleDown) 包裹 UnconstrainedBox(仅宽度受限)：
                // 内容按自然高度布局后整体等比缩放居中，正常视口比例 1.0
                // （像素不变），矮视口优雅降级不溢出
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: UnconstrainedBox(
                      constrainedAxis: Axis.horizontal,
                      child: EmptyState(
                        icon: Symbols.library_books_rounded,
                        title: context.l10n.emptyBookshelf,
                        kaomoji: true,
                      ),
                    ),
                  ),
          ),
        ],
      );
    }

    return CustomRefreshIndicator(
      onRefresh: () => ref.read(bookshelfNotifierProvider.notifier).refresh(),
      // [parity fix 2.0.264 补修 | 台账 1-3] LayoutBuilder 取视口实际宽度
      // 传给网格 sliver（SDK 无 SliverPadding.builder，box 层取宽后按
      // cellW×7/5+40 动态计算 cell aspect，封面恢复精确 5:7）
      child: LayoutBuilder(
        builder: (layoutContext, layoutConstraints) {
          final viewportWidth = layoutConstraints.maxWidth;
          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              // [骨架对齐 2.0.260 | 台账 1-3] 头部 = 可折叠大标题「书架」 +
              // 常驻分组 tab 行（bottom，对齐参考 03b 截图）；搜索入口收敛为
              // 顶栏 🔍 图标（_buildAppBarActions），页内全宽搜索条移除
              _buildHeaderSliver(context, ref, state),
              // [UI-fix 2.0.258] 批量模式摘要卡位于头部之后（对齐参考版：
              // 标题/Tab →「已选N本 · 共M本」胶囊 → 书列表）
              // 保留摘要所在的 sliver，避免选择态插入节点时重挂后面的书卡。
              SliverToBoxAdapter(
                child: state.isBatchMode
                    ? _buildBatchSummaryCard(context, ref, state)
                    : const SizedBox.shrink(),
              ),
              // 分组模式：渲染分组头 + 分组内容
              if (state.groupMode != GroupMode.none)
                ..._buildGroupedSlivers(context, ref, state, viewportWidth)
              else if (state.isGridView)
                _buildGridSliver(
                  context,
                  ref,
                  state.currentGroupBooks,
                  viewportWidth,
                )
              else
                _buildReorderableSliver(context, ref, state),
              // [UI_SYNC_REFACTOR T3] 底部批量工具条（batch 模式且选中时显示）
              if (state.isBatchMode && state.selectedUrls.isNotEmpty)
                SliverToBoxAdapter(
                  child: _buildBatchBottomBar(context, ref, state),
                ),
              const AppBottomBarSliverSpace(),
            ],
          );
        },
      ),
    );
  }

  /// 书架标题与操作按钮同排，分组页签常驻工具栏下方。
  Widget _buildHeaderSliver(
    BuildContext context,
    WidgetRef ref,
    BookshelfState state,
  ) {
    return LegadoTabRootHeaderSliver(
      large: false,
      title: Text(
        context.l10n.bookshelf,
        style: Theme.of(context).textTheme.headlineMedium
            ?.copyWith(fontSize: 28),
      ),
      // [UI-fix 2.0.258] 选择模式顶栏切换为批量动作集（全选/反选/删除/取消）
      actions: _animatedActions(context, state),
      // 分组 tab 行（TabBar 默认高 kToolbarHeight，Tab 高度 40dp）
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: _buildGroupTabBar(context, state),
      ),
    );
  }

  Widget _buildGridSliver(
    BuildContext context,
    WidgetRef ref,
    List<Book> books,
    double viewportWidth,
  ) {
    // 按选定列数计算卡片宽高，保留封面 5:7 与书名行的高度。
    final columns = ref.watch(
      bookshelfNotifierProvider.select((state) => state.gridColumns),
    );
    final available = viewportWidth - 44; // 扣除左右 padding 22×2
    return SliverPadding(
      // 内容边距：左右 22（参考边距 22px）+ 上下 8
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 8),
      sliver: SliverGrid.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          // 网格间距 20dp（参考卡列间距 20px）
          mainAxisSpacing: 20,
          crossAxisSpacing: 20,
          childAspectRatio: _bookshelfGridCellAspectRatio(available, columns),
        ),
        itemCount: books.length,
        itemBuilder: (context, index) =>
            _buildGridItem(context, ref, books[index]),
      ),
    );
  }

  /// 网格单元由 5:7 封面和 40dp 书名行组成。
  double _bookshelfGridCellAspectRatio(double availableWidth, int columns) {
    const crossSpacing = 20.0;
    const titleHeight = 40.0;
    final cellWidth = (availableWidth - (columns - 1) * crossSpacing) / columns;
    return cellWidth / (cellWidth * 7 / 5 + titleHeight);
  }

  Widget _buildReorderableSliver(
    BuildContext context,
    WidgetRef ref,
    BookshelfState state,
  ) {
    final shelfBooks = state.currentGroupBooks;
    return SliverReorderableList(
      itemCount: shelfBooks.length,
      // onReorderItem 的 newIndex 已按移除项调整，还原为 onReorder 语义后交给 Notifier
      onReorderItem: (oldIndex, newIndex) async {
        if (newIndex > oldIndex) newIndex++;
        await ref
            .read(bookshelfNotifierProvider.notifier)
            .reorderBook(oldIndex, newIndex);
      },
      itemBuilder: (context, index) =>
          _buildListItem(context, ref, shelfBooks[index]),
    );
  }

  /// 选择态复用普通条目，封面、隐私包装与 Hero 都保持挂载。— Codex + UI
  Widget _buildListItem(BuildContext context, WidgetRef ref, Book book) {
    final batch = ref.watch(
      bookshelfNotifierProvider.select((s) => s.isBatchMode),
    );
    final selected = ref.watch(
      bookshelfNotifierProvider.select(
        (s) => s.selectedUrls.contains(book.bookUrl),
      ),
    );
    return BookListItem(
      key: ValueKey(book.bookUrl),
      book: book,
      selectionMode: batch,
      selected: selected,
      onTap: () => batch
          ? ref
                .read(bookshelfNotifierProvider.notifier)
                .toggleSelect(book.bookUrl)
          : _openBook(context, ref, book),
      onLongPress: batch ? null : () => _openBookInfo(context, book),
    );
  }

  Widget _buildGridItem(BuildContext context, WidgetRef ref, Book book) {
    final batch = ref.watch(
      bookshelfNotifierProvider.select((s) => s.isBatchMode),
    );
    final selected = ref.watch(
      bookshelfNotifierProvider.select(
        (s) => s.selectedUrls.contains(book.bookUrl),
      ),
    );
    void onTap() {
      if (batch) {
        ref.read(bookshelfNotifierProvider.notifier).toggleSelect(book.bookUrl);
      } else {
        _openBook(context, ref, book);
      }
    }

    return RepaintBoundary(
      key: ValueKey(book.bookUrl),
      child: PrivacyMaskedContent(
        book: book,
        onTap: onTap,
        child: BookGridItem(
          title: book.name,
          coverUrl: book.customCoverUrl ?? book.coverUrl,
          sourceOrigin: book.origin,
          heroTag: 'book-cover:${book.bookUrl}',
          selectionMode: batch,
          selected: selected,
          onTap: onTap,
          onCoverLongPress: batch ? null : () => _openBookInfo(context, book),
          onInfoLongPress: batch ? null : () => _openBookInfo(context, book),
        ),
      ),
    );
  }

  // ===== 操作 =====

  /// 对齐参考版：单击按 BookType 直达阅读器或播放器，长按进入详情。— Codex + UI
  Future<void> _openBook(BuildContext context, WidgetRef ref, Book book) async {
    if (ModalRoute.of(context)?.isCurrent == false) return;
    final prepared = await ref
        .read(bookDetailServiceProvider)
        .resolveReading(book);
    if (!context.mounted || ModalRoute.of(context)?.isCurrent == false) return;
    final bookToOpen = prepared.book;
    final typeBits = prepared.typeBits;
    final route = BookOpenUtils.routeForTypeBits(typeBits);
    if (BookOpenUtils.needsReaderNotifier(route)) {
      ref.read(readerNotifierProvider.notifier).openBook(bookToOpen);
      await Navigator.pushNamed(
        context,
        route,
        arguments: BookCoverHero.originFor(context, bookToOpen.bookUrl),
      );
    } else {
      await Navigator.pushNamed(
        context,
        route,
        arguments: BookOpenUtils.argumentsForRoute(route, bookToOpen),
      );
    }
    // [队列⑫ P3 | 2026-09-22] 弹回书架后单本定向刷新（进度同步）
    if (!context.mounted) return;
    await _refreshBookOnReturn(context, ref, book);
  }

  /// [队列⑫ P3 | 2026-09-22] 从阅读器/详情页返回书架：单本定向刷新
  ///
  /// 上方 `await Navigator.pushNamed` 在阅读器或播放器弹回书架时才返回，
  /// 此刻重拉该书最新进度写回内存（BookshelfNotifier.refreshBook），
  /// 「刚读完的书」进度行/进度条随返回同步。不做整页重建、不新增 UI；
  /// 书若在阅读期间被移除，notifier 内部回退全量 refresh 保持一致。
  Future<void> _refreshBookOnReturn(
    BuildContext context,
    WidgetRef ref,
    Book book,
  ) async {
    if (!context.mounted) return;
    await ref
        .read(bookshelfNotifierProvider.notifier)
        .refreshBook(book.bookUrl);
  }

  /// 长按封面/书名直接打开书籍信息页（对齐安卓原版行为）
  void _openBookInfo(BuildContext context, Book book) {
    Navigator.pushNamed(context, AppRoutes.bookInfo, arguments: book);
  }

  /// 选择本地书籍文件并导入书架
  Future<void> _addLocalBook(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(bookshelfNotifierProvider.notifier);
    final errorColor = Theme.of(context).colorScheme.error;

    // [iOS 视角F C2] file_picker 8.x 的 iOS 端对 FileType.custom 逐个把扩展名
    // 解析为 UTI（UTTypeCreatePreferredIdentifierForTag）：解析不到（mobi/umd
    // 未在 iOS 注册）的扩展名被静默跳过（仅 [Skipping type] 日志）→ 选择器
    // 实际只剩 epub/txt/pdf 可选，而 Rust 内核支持 MOBI 解析——收窄扩展名
    // 列表会让 iOS 丢失 Android 已有的 mobi 导入能力。故 iOS 回落
    // FileType.any（全部文件可选，不可导入的格式由下方失败 SnackBar 显式
    // 报告）；Android 保持 custom 列表过滤（列表内容见下方注释）。
    // 注意：file_picker 8.3.7 Dart 侧在 type != custom 且 allowedExtensions
    // 非空时抛 ArgumentError，any 分支不得传列表。
    //
    // [cbz P1-1 | 2026-10-03] Android 白名单与导入页 import_screen.dart 的
    // _supportedFormats **同序同集合**（epub/txt/mobi/azw3/azw/pdf/umd/cbz，
    // 两处需同步维护，互指注释）：
    // · cbz 为「整本导入」格式（Rust 按 LOCAL|image 图片漫画包处理，
    //   不解压），缺失则该格式在 Android file_picker（FileType.custom）
    //   经 MimeTypeMap 过滤后被 DocumentsUI 置灰、无法选择（P1-1 回归，
    //   真机验证：本机 MimeTypeMap 将 .cbz 映射为 application/x-cbz）；
    // · zip/rar/7z 为压缩包格式，走导入页解压导入链路（_archiveFormats），
    //   不属于整本导入白名单。
    final result = Platform.isIOS
        ? await FilePicker.pickFiles(type: FileType.any)
        : await FilePicker.pickFiles(
            type: FileType.custom,
            allowedExtensions: const [
              'epub',
              'txt',
              'mobi',
              'azw3',
              'azw',
              'pdf',
              'umd',
              'cbz',
            ],
          );
    if (result.isEmpty) return;

    var successCount = 0;
    final failures = <String>[];
    // 失败原因显式化（体检 §三.13）：rust 侧对不支持的 MOBI 变体返回明确文案
    // （如「不支持 LZMA 压缩格式」「该 MOBI 文件已加密」），须透传给用户；
    // 详情最多展示 3 条，避免 SnackBar 溢出
    final failureDetails = <String>[];
    for (final file in result) {
      final path = file.path;
      if (path == null) {
        failures.add(file.name);
        continue;
      }
      // [iOS 视角F C1] iOS file_picker Import 模式把文件「移动」到 tmp；
      // 此处拷入持久 Documents/books/ 并改存「相对 Documents 可迁移标识」，
      // 避免 tmp 清理 / 重签名（容器 UUID 变化）后本地书失效（读侧以当前
      // 容器路径重建）。非 iOS 平台保持原绝对路径不变（兼容存量）。
      String toImport = path;
      if (Platform.isIOS) {
        try {
          toImport = await LocalBookStore.store(path);
        } catch (e) {
          failures.add(file.name);
          if (failureDetails.length < 3) {
            failureDetails.add(
              l10n.localBookSaveFailed(file.name, e.toString()),
            );
          }
          continue;
        }
      }
      try {
        await notifier.importLocalBook(toImport);
        successCount++;
      } catch (e) {
        failures.add(file.name);
        if (failureDetails.length < 3) {
          final msg = errorMessage(e);
          failureDetails.add('${file.name}：$msg');
        }
      }
    }

    // 刷新书架，确保与后端数据一致
    await notifier.refresh();

    final messages = <String>[];
    if (successCount > 0) messages.add(l10n.importedBookCount(successCount));
    if (failures.isNotEmpty) {
      final detail = failureDetails.join('；');
      final more = failures.length > failureDetails.length
          ? l10n.importFailureMore(failures.length)
          : '';
      messages.add(l10n.importBookFailed(detail, more));
    }
    // [iOS 视角F C2] UI 提示：any 选择器下选到不可导入的扩展名时，
    // 显式说明「显示全部文件、仅电子书格式可导入」，避免静默困惑
    if (Platform.isIOS) {
      // 与上方 Android 白名单及 import_screen.dart::_supportedFormats
      // 同集合（azw3/azw 为 KF8 MOBI、cbz 为整本导入漫画包，均可导入）
      const importable = {
        'epub',
        'txt',
        'mobi',
        'azw3',
        'azw',
        'pdf',
        'umd',
        'cbz',
      };
      final pickedExts = result
          .map((f) => f.name.split('.').last.toLowerCase())
          .where((e) => e.isNotEmpty)
          .toSet();
      if (pickedExts.difference(importable).isNotEmpty) {
        messages.add(l10n.iosBookPickerHint);
      }
    }
    if (messages.isEmpty) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(messages.join('；')),
        backgroundColor: successCount == 0 ? errorColor : null,
      ),
    );
  }

  // ===== 分组展示 =====

  /// 构建分组 slivers：每组一个头部 + 网格/列表
  /// [viewportWidth] 视口实际宽度（[parity fix 2.0.264 补修] 网格 cell
  /// aspect 动态计算用，经上层 LayoutBuilder 传入）
  List<Widget> _buildGroupedSlivers(
    BuildContext context,
    WidgetRef ref,
    BookshelfState state,
    double viewportWidth,
  ) {
    final groups = state.groupedBooks;
    final slivers = <Widget>[];
    for (final entry in groups.entries) {
      final groupTitle = switch (state.groupMode) {
        GroupMode.none => context.l10n.allBooks,
        GroupMode.bySource
            when entry.value.isNotEmpty &&
                entry.value.first.originName.isEmpty =>
          context.l10n.localBooks,
        GroupMode.byGroup when entry.value.isNotEmpty =>
          entry.value.first.group > 0
              ? context.l10n.bookGroupNumber(entry.value.first.group)
              : context.l10n.defaultBookGroup,
        _ => entry.key,
      };
      // 分组头
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  groupTitle,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                Text(
                  '${entry.value.length}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      // 分组内容
      if (state.isGridView) {
        slivers.add(_buildGridSliver(context, ref, entry.value, viewportWidth));
      } else {
        slivers.add(_buildListSliver(context, ref, entry.value));
      }
    }
    return slivers;
  }

  /// 列表模式（非拖拽，用于分组内展示）
  Widget _buildListSliver(
    BuildContext context,
    WidgetRef ref,
    List<Book> books,
  ) {
    return SliverList.builder(
      itemCount: books.length,
      itemBuilder: (context, index) =>
          _buildListItem(context, ref, books[index]),
    );
  }

  void _handleMenuAction(BuildContext context, WidgetRef ref, String action) {
    switch (action) {
      case 'update_all':
        // [UI-fix v2.0.2 | 2026-08-06] 更新目录接通真实 refreshToc FFI（对标原版 updateBook 逐本刷新） — Qoder
        _updateAllBooks();
      case 'import':
        // 原版添加本地：直接选择本地书籍文件导入
        _addLocalBook(context, ref);
      case 'remote':
        Navigator.pushNamed(context, AppRoutes.remoteBooks);
      case 'add_url':
        // [UI-fix v2.0.2 | 2026-08-06] 添加网址接通 WebBook 入库链路（对标原版 addBookByUrl） — Qoder
        _showAddByUrlDialog();
      case 'select_mode':
        ref.read(bookshelfNotifierProvider.notifier).toggleBatchMode();
        break;
      case 'manage':
        // 进入书架管理页（对标原版 BookshelfManageActivity）
        Navigator.pushNamed(context, AppRoutes.bookshelfManage);
      case 'offline_cache':
        // [UI-fix v2.0.17 | 2026-08-11] 离线缓存页（对齐原版书架菜单
        // menu_download → CacheActivity：书籍列表/缓存进度/下载控制/单本导出）
        // — Reasonix
        Navigator.pushNamed(context, AppRoutes.offlineCache);
      case 'groups':
        Navigator.pushNamed(context, AppRoutes.bookGroups);
      case 'layout':
        _showLayoutDialog();
      case 'export_list':
        // [UI-fix v2.0.2 | 2026-08-06] 导出书单对齐 Kotlin exportBookshelf（JSON 数组文件） — Qoder
        _exportBookshelf();
      case 'import_list':
        // [UI-fix v2.0.2 | 2026-08-06] 导入书单对齐 Kotlin importBookshelf（url/json/文件） — Qoder
        _showImportBookshelfDialog();
      case 'log':
        // [UI-fix v2.0.1 | 2026-08-06] 日志菜单接通 AppLogScreen（对标原版 menu_log → AppLogDialog） — Qoder
        Navigator.pushNamed(context, AppRoutes.appLog);
    }
  }

  Future<void> _showLayoutDialog() async {
    final state = ref.read(bookshelfNotifierProvider);
    var layout = state.isGridView ? state.gridColumns : 0;
    var groupMode = state.groupMode;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.layoutSettings),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownMenu<int>(
                initialSelection: layout,
                selectOnly: true,
                expandedInsets: EdgeInsets.zero,
                label: Text(context.l10n.layoutStyle),
                dropdownMenuEntries: [
                  DropdownMenuEntry(value: 0, label: context.l10n.listLayout),
                  for (var columns = 2; columns <= 6; columns++)
                    DropdownMenuEntry(
                      value: columns,
                      label: context.l10n.gridColumnCount(columns),
                    ),
                ],
                onSelected: (value) {
                  if (value != null) layout = value;
                },
              ),
              const SizedBox(height: 20),
              DropdownMenu<GroupMode>(
                initialSelection: groupMode,
                selectOnly: true,
                expandedInsets: EdgeInsets.zero,
                label: Text(context.l10n.groupStyle),
                dropdownMenuEntries: [
                  DropdownMenuEntry(
                    value: GroupMode.none,
                    label: context.l10n.groupByNone,
                  ),
                  DropdownMenuEntry(
                    value: GroupMode.bySource,
                    label: context.l10n.groupBySourceLabel,
                  ),
                  DropdownMenuEntry(
                    value: GroupMode.byGroup,
                    label: context.l10n.groupByGroup,
                  ),
                ],
                onSelected: (value) {
                  if (value != null) groupMode = value;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _saveDisplaySettings(
      () => ref
          .read(bookshelfNotifierProvider.notifier)
          .setLayout(
            isGridView: layout != 0,
            gridColumns: layout == 0 ? state.gridColumns : layout,
            groupMode: groupMode,
          ),
    );
  }

  /// 导出书单（对标 Kotlin BookshelfViewModel.exportBookshelf）：
  /// [UI-fix v2.0.2 | 2026-08-06] JSON 数组 [{name,author,intro}] 2 空格缩进，
  /// 输出 bookshelf.json 供分享（原版行为对齐） — Qoder
  Future<void> _exportBookshelf() async {
    final books = ref.read(bookshelfNotifierProvider).books;
    if (books.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.emptyExportBookList)));
      return;
    }
    final data = books
        .map(
          (b) => {
            'name': b.name,
            'author': b.author,
            'intro': b.customIntro ?? b.intro ?? '',
          },
        )
        .toList();
    final json = const JsonEncoder.withIndent('  ').convert(data);
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            utf8.encode(json),
            name: 'bookshelf.json',
            mimeType: 'application/json',
          ),
        ],
      ),
    );
  }

  // ===== [UI-fix v2.0.2 | 2026-08-06] 更新目录 / 添加网址 / 导入书单 — Qoder =====

  /// 更新全部书籍目录（对标 Kotlin updateAllBooks：仅刷新允许更新的非本地书）
  Future<void> _updateAllBooks() async {
    final l10n = context.l10n;

    final books = ref.read(bookshelfNotifierProvider).books;
    final targets = books
        .where(
          (b) =>
              b.canUpdate &&
              b.origin != BookType.localTag &&
              !b.origin.startsWith(BookType.webDavTag),
        )
        .toList();
    if (targets.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.noBooksToUpdate)));
      return;
    }
    final progress = ValueNotifier<String>(l10n.preparing);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ValueListenableBuilder<String>(
        valueListenable: progress,
        builder: (context, text, _) => AlertDialog(
          content: Row(
            children: [
              // [STAGE-UI-P43UNIFY2 B3] 裸环换接统一封装（线宽口径：保留
              // 2dp 实参；参考版主流默认 4dp 由封装默认承载）
              const SizedBox(
                width: 24,
                height: 24,
                child: AppCircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 16),
              Expanded(child: Text(text)),
            ],
          ),
        ),
      ),
    );
    var ok = 0;
    for (var i = 0; i < targets.length; i++) {
      final book = targets[i];
      progress.value = l10n.updatingBook(i + 1, targets.length, book.name);
      try {
        await ref
            .read(readingRepositoryProvider)
            .refreshToc(book.bookUrl, book.origin);
        ok++;
      } catch (e) {
        debugPrint('更新目录失败《${book.name}》: $e');
      }
    }
    if (!mounted) {
      progress.dispose();
      return;
    }
    Navigator.pop(context); // 关闭进度对话框
    progress.dispose();
    ref.read(bookshelfNotifierProvider.notifier).refresh();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.bookTocUpdateFinished(ok, targets.length))),
    );
  }

  /// 添加网址对话框（对标 Kotlin showAddBookByUrlAlert，扩展书名字段作裸书兑底）
  Future<void> _showAddByUrlDialog() async {
    // 输入框拥有内部控制器，避免对话框退场动画期间提前释放。— Codex + UI
    var urlInput = '';
    var nameInput = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.addBookUrl),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                onChanged: (value) => urlInput = value,
                maxLines: 3,
                decoration: InputDecoration(hintText: context.l10n.bookUrlHint),
              ),
              const SizedBox(height: 12),
              TextField(
                onChanged: (value) => nameInput = value,
                decoration: InputDecoration(
                  hintText: context.l10n.bookNameOptionalHint,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.l10n.confirm),
          ),
        ],
      ),
    );
    final urls = urlInput
        .split(RegExp(r'[\n,;]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final fallbackName = nameInput.trim();
    if (confirmed != true || urls.isEmpty || !mounted) return;
    await _addBooksByUrl(urls, fallbackName);
  }

  /// 输入与结果提示留在页面，网址添加由应用层编排。
  Future<void> _addBooksByUrl(List<String> urls, String fallbackName) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await ref
        .read(bookshelfImportControllerProvider)
        .addByUrls(urls, fallbackName);
    if (!mounted) return;
    ref.read(bookshelfNotifierProvider.notifier).refresh();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.addBookUrlFinished(
            result.added,
            result.skipped,
            result.failed,
          ),
        ),
      ),
    );
  }

  /// 导入书单对话框（对标 Kotlin importBookshelfAlert：
  /// url/json 输入框 + 选择 txt/json 文件）
  Future<void> _showImportBookshelfDialog() async {
    final input = await showDialog<String>(
      context: context,
      builder: (_) => const _BookshelfImportDialog(),
    );
    if (input == null || input.isEmpty || !mounted) return;
    await _importBookshelf(input);
  }

  /// 页面只处理展示和刷新，不参与网络、搜索与入架。
  Future<void> _importBookshelf(String input) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await ref
        .read(bookshelfImportControllerProvider)
        .importBookshelf(input);
    if (!mounted) return;
    if (result is BookshelfImportSummary) {
      ref.read(bookshelfNotifierProvider.notifier).refresh();
    }
    final message = switch (result) {
      BookshelfImportFetchFailed(:final error) =>
        context.l10n.bookListFetchFailed(error.toString()),
      BookshelfImportInvalid() => context.l10n.invalidBookList,
      BookshelfImportSummary(:final added, :final skipped, :final failed) =>
        context.l10n.bookListImportFinished(added, skipped, failed),
    };
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  /// 选择模式「已选N本 · 共M本」胶囊（对齐参考版 05 截图：× 退出钮 + 计数）
  ///
  /// [UI-fix 2.0.258] 根因修复：此前本卡构建为 `Positioned` 子树却挂在
  /// SliverToBoxAdapter（非 Stack 父级）下，布局期抛异常（debug 报
  /// "A Positioned widget must be wrapped with its parent"，release
  /// 帧渲染中断），导致选择模式整屏灰白空白（台账 1-5 P0）。
  /// 现改为常规 Center 布局，不再依赖 Stack 定位。
  Widget _buildBatchSummaryCard(
    BuildContext context,
    WidgetRef ref,
    BookshelfState state,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
        child: Material(
          color: cs.surfaceContainer,
          borderRadius: BorderRadius.circular(32),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: context.l10n.exitSelection,
                  onPressed: () => ref
                      .read(bookshelfNotifierProvider.notifier)
                      .toggleBatchMode(),
                ),
                Text(
                  context.l10n.selectedBookCount(state.selectedUrls.length),
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  context.l10n.groupBookCount(state.currentGroupBooks.length),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// [UI_SYNC_REFACTOR T3] 底部批量工具条（对齐参考 SelectionBottomBar）
  Widget _buildBatchBottomBar(
    BuildContext context,
    WidgetRef ref,
    BookshelfState state,
  ) {
    final cs = Theme.of(context).colorScheme;
    final count = state.selectedUrls.length;
    if (count == 0) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(
          color: cs.surfaceContainer,
          borderRadius: BorderRadius.circular(32),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: const Icon(Icons.select_all),
              tooltip: context.l10n.selectAll,
              onPressed: () =>
                  ref.read(bookshelfNotifierProvider.notifier).selectAll(),
            ),
            IconButton(
              icon: const Icon(Icons.flip_rounded),
              tooltip: context.l10n.invertSelection,
              onPressed: () => ref
                  .read(bookshelfNotifierProvider.notifier)
                  .invertSelection(),
            ),
            IconButton(
              icon: const Icon(Icons.download_rounded),
              tooltip: context.l10n.batchDownload,
              onPressed: count > 0
                  ? () => _showSnack(context.l10n.batchDownloadCount(count))
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.drive_file_move_rounded),
              tooltip: context.l10n.moveBookGroup,
              onPressed: count > 0
                  ? () => _showSnack(context.l10n.moveBookGroupCount(count))
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }
}

/// 控制器与对话框同生命周期，关闭动画结束后由State释放。— Codex + UI
class _BookshelfImportDialog extends StatefulWidget {
  const _BookshelfImportDialog();

  @override
  State<_BookshelfImportDialog> createState() => _BookshelfImportDialogState();
}

class _BookshelfImportDialogState extends State<_BookshelfImportDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.importBookList),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _controller,
          maxLines: 4,
          decoration: InputDecoration(hintText: context.l10n.bookListInputHint),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () async {
              final picked = await FilePicker.pickFile(
                type: FileType.custom,
                allowedExtensions: const ['txt', 'json'],
              );
              final path = picked?.path;
              if (path != null) {
                try {
                  final content = await File(path).readAsString();
                  if (mounted) _controller.text = content;
                } catch (e) {
                  debugPrint('读取书单文件失败: $e');
                }
              }
            },
            child: Text(context.l10n.chooseBookListFile),
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text.trim()),
        child: Text(context.l10n.importAction),
      ),
    ],
  );
}
