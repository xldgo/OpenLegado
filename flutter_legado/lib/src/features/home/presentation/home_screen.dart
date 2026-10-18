import 'package:material_ui/material_ui.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:material_symbols_icons/symbols.dart';

import '../../../l10n/app_localization.dart';
import '../../bookshelf/bookshelf.dart';
import '../../../app/routing/route_names.dart';
import '../../../widgets/app_scaffold.dart';
import '../../../widgets/navigation/app_navigation_bars.dart';
import '../../appearance/application/bottom_bar_skin_notifier.dart';
import '../application/main_prefs_notifier.dart';
import '../../../providers/theme/system_bar_notifier.dart';
import '../../../providers/ui_settings/ui_settings_notifier.dart';
import '../../explore/presentation/explore_screen.dart';
import 'home_tab_screen.dart';
import '../../rss/presentation/rss_screen.dart';
import '../../settings/presentation/settings_screen.dart';

/// 首页 - 底部 Tab 导航 + 左右滑动切页
///
/// 对齐安卓原版 MainActivity（activity_main.xml）：
/// - ViewPager（左右滑动切页）与 BottomNavigationView（图标底栏）并存
/// - 双击底栏项（300ms 内）：书架页回滚顶部 / 发现页收起展开项
///   （对标 onNavigationItemReselected → gotoTop/compressExplore）
/// - 返回键两段式：非书架页先回书架页；书架页 2 秒内二次返回退出
///   （对标 onBackPressedDispatcher + double_click_exit）
/// - [UI-fix v2.0.5 | 2026-08-08] 接通其他设置页主界面分组：显示发现/
///   显示订阅控制 Tab 显隐、默认首页控制启动落地页
///   （对标原版 AppConfig.showDiscovery/showRSS/defaultHomePage） — Qoder
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

/// 首页逻辑 Tab（与底栏索引解耦，便于按偏好动态显隐）
/// [UI_SYNC_REFACTOR S6 | 2026-09-08] 新增 home 首页页签（对齐参考版首页）— Qoder
enum _HomeTab { home, bookshelf, explore, rss, my }

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// 底栏双击判定窗口（对标原版 bookshelfReselected/exploreReselected 300ms）
  static const _reselectInterval = Duration(milliseconds: 300);

  /// 返回键双击退出判定窗口（对标原版 EXIT_INTERVAL = 2000ms）
  static const _exitInterval = Duration(seconds: 2);

  int _openSettingsRequest = 0;
  // [UI_SYNC_REFACTOR S1] 滑动切页控制器（对齐参考 MainScreen
  // HorizontalPager userScrollEnabled=true；2026-09-05 拉源码核实，
  // 早前审计 IndexedStack 口径系误读——原版本就是 ViewPager 滑动）
  // [UI_SYNC_REFACTOR S6 | 2026-09-08] 首页页签恒为索引 0，书架恒为索引 1
  //（默认主页=书架，与既有默认主页偏好语义一致）；默认主页跳转逻辑不变 — Qoder
  final PageController _pageController = PageController(initialPage: 1);

  /// 当前逻辑 Tab（Tab 显隐变化时据此重新定位索引）
  _HomeTab _currentTab = _HomeTab.bookshelf;

  List<_HomeTab> _renderedTabs = const [
    _HomeTab.home,
    _HomeTab.bookshelf,
    _HomeTab.explore,
    _HomeTab.rss,
    _HomeTab.my,
  ];
  int _navigationRevision = 0;
  int? _pendingPageSync;

  /// 已访问过的 Tab 集合（首屏默认访问书架）— 保留懒构建语义
  /// [UI_SYNC_REFACTOR S6] 首页页签相邻预载，一并加入初始集 — Qoder
  final Set<_HomeTab> _visitedTabs = {_HomeTab.home, _HomeTab.bookshelf};

  /// 书架页回滚顶部信号（双击书架底栏项时自增）
  final ValueNotifier<int> _bookshelfScrollTopSignal = ValueNotifier(0);

  /// 发现页收起展开项信号（双击发现底栏项时自增）
  final ValueNotifier<int> _exploreCollapseSignal = ValueNotifier(0);

  DateTime? _lastTapTime;
  _HomeTab? _lastTappedTab;
  DateTime? _lastBackTime;

  /// 默认首页是否已应用（偏好异步加载完成后仅跳转一次）
  bool _defaultHomePageApplied = false;

  @override
  void dispose() {
    _pageController.dispose();
    _bookshelfScrollTopSignal.dispose();
    _exploreCollapseSignal.dispose();
    super.dispose();
  }

  /// 按主界面偏好计算可见 Tab 列表（对标原版 showDiscovery/showRSS 显隐）
  /// [UI_SYNC_REFACTOR S6 | 2026-09-08] 新增首页页签（最近阅读+统计+目标表盘，
  /// 对齐参考版首页；恒显示，模块管理登记后续批次）— Qoder
  List<_HomeTab> _visibleTabs(MainPrefsState prefs) => [
    _HomeTab.home,
    _HomeTab.bookshelf,
    if (prefs.showDiscovery) _HomeTab.explore,
    if (prefs.showRss) _HomeTab.rss,
    _HomeTab.my,
  ];

  /// 默认首页偏好值 → 逻辑 Tab（对标原版 defaultHomePage 数组值）
  /// [UI_SYNC_REFACTOR S6 | 2026-09-08] 新增首页页签后补 'home' 映射 — Qoder
  _HomeTab _tabOfHomePage(String value) {
    switch (value) {
      case 'home':
        return _HomeTab.home;
      case 'explore':
        return _HomeTab.explore;
      case 'rss':
        return _HomeTab.rss;
      case 'my':
        return _HomeTab.my;
      default:
        return _HomeTab.bookshelf;
    }
  }

  void _onDestinationSelected(List<_HomeTab> tabs, int index) {
    if (index < 0 || index >= tabs.length) return;
    // 用户已明确选择页面，晚到的默认首页不能再接管导航。
    _defaultHomePageApplied = true;
    final now = DateTime.now();
    final tab = tabs[index];
    // 双击检测：300ms 内再次点击当前选中项 → 触发 reselect 动作
    if (tab == _currentTab &&
        _lastTappedTab == tab &&
        _lastTapTime != null &&
        now.difference(_lastTapTime!) <= _reselectInterval) {
      _lastTapTime = null;
      _onReselect(tab);
      return;
    }
    _lastTapTime = now;
    _lastTappedTab = tab;
    if (tab != _currentTab) {
      // 对标原版 setCurrentItem(position, false)：无过渡动画
      // [UI_SYNC_REFACTOR S1] PageView 跳页（滑动切页开启，同参考 HorizontalPager）
      _navigateTo(tab);
    }
  }

  /// 导航身份使用逻辑页签，索引只在当前可见集合中计算。— Codex + UI
  void _navigateTo(_HomeTab tab) {
    final tabs = _visibleTabs(ref.read(mainPrefsProvider));
    final index = tabs.indexOf(tab);
    if (index < 0) return;
    _navigationRevision++;
    _pendingPageSync = null;
    setState(() {
      _currentTab = tab;
      _visitedTabs.add(tab);
    });
    if (_pageController.hasClients) _pageController.jumpToPage(index);
  }

  /// 在新页面集合完成布局后恢复位置，旧回调不能覆盖后来的点击或设置。
  void _synchronizePages(List<_HomeTab> tabs) {
    final revision = ++_navigationRevision;
    _pendingPageSync = revision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || revision != _navigationRevision) return;
      if (!listEquals(tabs, _visibleTabs(ref.read(mainPrefsProvider)))) return;
      final index = tabs.indexOf(_currentTab);
      if (_pageController.hasClients && index >= 0) {
        _pageController.jumpToPage(index);
      }
      _pendingPageSync = null;
    });
  }

  /// 首页设置快捷入口：切到我的页并定位其他分组。
  void _openMySettings() {
    final tabs = _visibleTabs(ref.read(mainPrefsProvider));
    setState(() => _openSettingsRequest++);
    _onDestinationSelected(tabs, tabs.indexOf(_HomeTab.my));
  }

  /// 底栏双击动作（对标 onNavigationItemReselected）
  void _onReselect(_HomeTab tab) {
    switch (tab) {
      case _HomeTab.bookshelf: // 书架：gotoTop
        _bookshelfScrollTopSignal.value++;
      case _HomeTab.explore: // 发现：compressExplore（收起已展开的分类）
        _exploreCollapseSignal.value++;
      default:
        break;
    }
  }

  void _onPageChanged(List<_HomeTab> tabs, int index, int revision) {
    if (revision != _navigationRevision ||
        _pendingPageSync != null ||
        !listEquals(tabs, _renderedTabs) ||
        !listEquals(tabs, _visibleTabs(ref.read(mainPrefsProvider))) ||
        index < 0 ||
        index >= tabs.length ||
        tabs[index] == _currentTab) {
      return;
    }
    _defaultHomePageApplied = true;
    setState(() {
      _currentTab = tabs[index];
      _visitedTabs.add(_currentTab);
    });
  }

  /// 返回键两段式处理（对标 MainActivity.onBackPressedDispatcher）
  Future<void> _handleBack() async {
    _defaultHomePageApplied = true;
    if (_currentTab != _HomeTab.bookshelf) {
      _navigateTo(_HomeTab.bookshelf);
      return;
    }
    final now = DateTime.now();
    if (_lastBackTime != null &&
        now.difference(_lastBackTime!) <= _exitInterval) {
      await SystemNavigator.pop();
      return;
    }
    _lastBackTime = now;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(context.l10n.doubleClickExit),
          duration: _exitInterval,
        ),
      );
  }

  /// 逻辑 Tab → 页面内容（未访问过的 Tab 用占位以保留懒构建语义）
  Widget _pageOf(_HomeTab tab) {
    switch (tab) {
      case _HomeTab.home:
        return _visitedTabs.contains(tab)
            ? HomeTabScreen(onOpenSettings: _openMySettings)
            : const SizedBox.shrink();
      case _HomeTab.bookshelf:
        return BookshelfScreen(scrollTopSignal: _bookshelfScrollTopSignal);
      case _HomeTab.explore:
        return _visitedTabs.contains(tab)
            ? ExploreScreen(collapseSignal: _exploreCollapseSignal)
            : const SizedBox.shrink();
      case _HomeTab.rss:
        return _visitedTabs.contains(tab)
            ? const RssScreen()
            : const SizedBox.shrink();
      case _HomeTab.my:
        return _visitedTabs.contains(tab)
            ? SettingsScreen(openSettingsRequest: _openSettingsRequest)
            : const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(mainPrefsProvider);
    final skinState = ref.watch(bottomBarSkinProvider);
    final activeSkin = skinState.active;
    final tabs = _visibleTabs(prefs);
    final previousTab = _currentTab;
    // 同时处理仓储预加载和异步加载；只在首次加载成功后应用默认页。
    if (!_defaultHomePageApplied && prefs.loaded) {
      _defaultHomePageApplied = true;
      final target = _tabOfHomePage(prefs.defaultHomePage);
      _currentTab = tabs.contains(target) ? target : _HomeTab.bookshelf;
    }
    if (!tabs.contains(_currentTab)) {
      _currentTab = _HomeTab.bookshelf;
    }
    final tabsChanged = !listEquals(tabs, _renderedTabs);
    _renderedTabs = tabs;
    _visitedTabs.add(_currentTab);
    if (tabsChanged || previousTab != _currentTab) {
      if (tabsChanged) {
        _lastTappedTab = null;
        _lastTapTime = null;
      }
      _synchronizePages(tabs);
    }
    final currentIndex = tabs.indexOf(_currentTab);
    final navigationRevision = _navigationRevision;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final ui = ref.watch(uiSettingsProvider);
          final useRail = _railActive(
            ui,
            constraints.maxWidth,
            MediaQuery.of(context).orientation,
          );
          final pageArea = NotificationListener<ScrollStartNotification>(
            onNotification: (notification) {
              // 手势开始时即确认用户导航意图，不等到切页完成才阻止晚到默认页。
              if (notification.depth == 0 && notification.dragDetails != null) {
                _defaultHomePageApplied = true;
              }
              return false;
            },
            child: PageView(
              controller: _pageController,
              // [UI_SYNC_REFACTOR S1] 滑动切页（对齐参考 HorizontalPager
              // userScrollEnabled=true；allowImplicitScrolling≈预载相邻页）
              physics: const ClampingScrollPhysics(),
              allowImplicitScrolling: true,
              onPageChanged: (index) =>
                  _onPageChanged(tabs, index, navigationRevision),
              children: [
                for (final tab in tabs)
                  _KeepAlivePage(key: ValueKey(tab), child: _pageOf(tab)),
              ],
            ),
          );
          // [GLOBALCOMP B4] 页壳统一：AppScaffold（行为等价直通 Scaffold）
          return AppScaffold(
            // 沉浸式状态栏开启时顶栏延伸至状态栏区域（对标原版 fullScreen +
            // AppConfig.isTransparentStatusBar）；关闭时保留顶部 SafeArea
            body: SafeArea(
              top: !ref.watch(
                systemBarProvider.select((s) => s.transparentStatusBar),
              ),
              bottom: false,
              // [UI_SYNC_REFACTOR B3] tabletInterface + sw≥600 切 NavigationRail
              //（简版：系统图标不带皮肤，expand 持久化登记差异延后）
              // 保持页面容器层级稳定，切换导航形态时不重建当前页。
              child: Row(
                children: [
                  if (useRail) ...[
                    _buildRail(ui, tabs, currentIndex),
                    const VerticalDivider(width: 1, thickness: 0),
                  ],
                  Expanded(
                    key: const ValueKey('home-page-area'),
                    child: pageArea,
                  ),
                ],
              ),
            ),
            // [UI_SYNC_REFACTOR B3] 底栏三形态：隐藏 / 悬浮 64dp 胶囊 / 标准
            // NavigationBar（label 三档 + 透明度）；皮肤图标两种形态均保留
            // 侧栏与底栏互斥，横竖屏切换时保留当前页签。
            bottomBar: useRail
                ? null
                : _buildBottomBar(context, ui, tabs, currentIndex, activeSkin),
          );
        },
      ),
    );
  }

  /// 导航项规格（三态底栏统一消费源）
  List<AppNavSpec> _specsFor(List<_HomeTab> tabs) => [
    for (final tab in tabs)
      switch (tab) {
        // [UI_SYNC_REFACTOR S6] 首页页签底栏项（新皮肤槽位，无皮肤回退 symbol）
        _HomeTab.home => AppNavSpec(
          symbol: Symbols.home_rounded,
          label: context.l10n.home,
          skinSlot: 'home_page',
        ),
        _HomeTab.bookshelf => AppNavSpec(
          symbol: Symbols.menu_book_rounded,
          label: context.l10n.bookshelf,
          skinSlot: 'bookshelf',
        ),
        _HomeTab.explore => AppNavSpec(
          symbol: Symbols.explore_rounded,
          label: context.l10n.discover,
          skinSlot: 'home',
        ),
        _HomeTab.rss => AppNavSpec(
          // [parity C3 B5] 订阅页签图标改 RSS 选形：参考底栏第 4 项
          // 为经典 RSS（左下圆点 + 双弧，量测 ref 01 底栏），原
          // feed_rounded 为报纸/文档版式（参考判为「文档图标」），
          // 改 rss_feed_rounded 对齐
          symbol: Symbols.rss_feed_rounded,
          label: context.l10n.rss,
          skinSlot: 'notes',
        ),
        _HomeTab.my => AppNavSpec(
          symbol: Symbols.person_rounded,
          label: context.l10n.my,
          skinSlot: 'settings',
        ),
      },
  ];

  /// Rail 激活判定（对齐参考仓 tabletInterface：auto/always/landscape/off）
  bool _railActive(UiSettings ui, double width, Orientation orientation) {
    switch (ui.tabletInterface) {
      case TabletInterfaceMode.always:
        return true;
      case TabletInterfaceMode.landscape:
        return orientation == Orientation.landscape;
      case TabletInterfaceMode.off:
        return false;
      case TabletInterfaceMode.auto:
        return width >= 600;
    }
  }

  /// 大屏侧栏：分组选择先定位到书架，再更新与页内共用的分组状态。
  Widget _buildRail(UiSettings ui, List<_HomeTab> tabs, int currentIndex) {
    final bookshelf = ref.watch(bookshelfNotifierProvider);
    return AppRailBar(
      specs: _specsFor(tabs),
      currentIndex: currentIndex,
      activeSkin: ref.watch(bottomBarSkinProvider.select((s) => s.active)),
      extended: ui.railExtended,
      onSelect: (index) => _onDestinationSelected(tabs, index),
      onToggleExtended: () => _saveRailExtended(!ui.railExtended),
      onSearch: () => Navigator.of(context).pushNamed(AppRoutes.search),
      bookshelfIndex: tabs.indexOf(_HomeTab.bookshelf),
      groups: [
        for (final g in bookshelf.groups) bookshelfGroupLabel(context, g),
      ],
      selectedGroupIndex: bookshelf.selectedGroupIndex,
      onGroupSelected: (index) async {
        _onDestinationSelected(tabs, tabs.indexOf(_HomeTab.bookshelf));
        try {
          await ref.read(bookshelfNotifierProvider.notifier).selectGroup(index);
        } catch (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.l10n.loginSaveFailed)),
            );
          }
        }
      },
    );
  }

  Future<void> _saveRailExtended(bool extended) async {
    try {
      await ref.read(uiSettingsProvider.notifier).setRailExtended(extended);
    } catch (error) {
      debugPrint('侧栏布局保存失败：$error');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.loginSaveFailed)));
      }
    }
  }

  /// 底栏构建：隐藏 / 悬浮胶囊 / 标准 NavigationBar（label 三档+透明度）
  Widget? _buildBottomBar(
    BuildContext context,
    UiSettings ui,
    List<_HomeTab> tabs,
    int currentIndex,
    String activeSkin,
  ) {
    if (!ui.showBottomView) return null;
    if (ui.useFloatingBottomBar) {
      return AppFloatingBottomBar(
        specs: _specsFor(tabs),
        currentIndex: currentIndex,
        activeSkin: activeSkin,
        onSelect: (index) => _onDestinationSelected(tabs, index),
        useBlur: ui.enableBlur,
        blurRadius: ui.bottomBarBlurRadius,
        blurAlpha: ui.bottomBarBlurAlpha,
      );
    }
    return AppShortNavigationBar(
      specs: _specsFor(tabs),
      currentIndex: currentIndex,
      activeSkin: activeSkin,
      labelBehavior: switch (ui.labelVisibilityMode) {
        BottomBarLabelMode.auto =>
          NavigationDestinationLabelBehavior.onlyShowSelected,
        BottomBarLabelMode.labeled =>
          NavigationDestinationLabelBehavior.alwaysShow,
        BottomBarLabelMode.unlabeled =>
          NavigationDestinationLabelBehavior.alwaysHide,
      },
      opacity: ui.bottomBarOpacity / 100,
      onSelect: (index) => _onDestinationSelected(tabs, index),
    );
  }
}

/// [UI_SYNC_REFACTOR S1] 页保活（对齐参考 HorizontalPager
/// beyondViewportPageCount=4：全部页常驻不销毁，懒构建语义保留）
class _KeepAlivePage extends StatefulWidget {
  final Widget child;

  const _KeepAlivePage({super.key, required this.child});

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
