import '../fixtures/app_test_api.dart';

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/data/repositories/mock_read_record_repository.dart';
import 'package:flutter_legado/src/features/home/application/main_prefs_notifier.dart';
import 'package:flutter_legado/src/features/rss/application/rss_notifier.dart'
    show kRssSourceVersion, kRssSourceVersionKey;
import 'package:flutter_legado/src/providers/home_settings_provider.dart';
import 'package:flutter_legado/src/data/repositories/app_home_settings_repository.dart';
import 'package:flutter_legado/src/data/services/app_settings_service.dart';
import 'package:flutter_legado/src/domain/contracts/home_settings_repository.dart';
import 'package:flutter_legado/src/domain/models/app_settings_snapshot.dart';
import 'package:flutter_legado/src/features/bookshelf/bookshelf.dart';
import 'package:flutter_legado/src/features/explore/presentation/explore_screen.dart';
import 'package:flutter_legado/src/features/home/presentation/home_screen.dart';
import 'package:flutter_legado/src/features/home/presentation/home_tab_screen.dart';
import 'package:flutter_legado/src/features/settings/presentation/settings_screen.dart';

import '../mocks/mocks.dart';
import '../fixtures/home_settings_storage.dart';

/// 主框架导航对齐验证（对标原版 MainActivity：
/// PageView 滑动切页（对齐参考 HorizontalPager）+ BottomNavigationView 并存、
/// 双击回顶、返回键两段式）
/// [UI_SYNC_REFACTOR S6 | 2026-09-08] 新增首页页签后更新为五页签结构：
/// 首页(0)/书架(1)/发现(2)/订阅(3)/我的(4)，默认主页仍为书架 — Qoder
void main() {
  setUpAll(registerFallbacks);

  Future<void> pumpHome(
    WidgetTester tester,
    MockRustApi mockApi, {
    Map<String, Object> preferences = const {},
    HomeSettingsRepository? mainPreferences,
  }) async {
    // 既有底栏交互用例使用手机窗口，避免默认宽窗口启用侧栏。
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // 本文件只验证导航，默认 RSS 资源导入由独立用例覆盖。
    SharedPreferences.setMockInitialValues({
      kRssSourceVersionKey: kRssSourceVersion,
      ...preferences,
    });
    when(() => mockApi.bookshelfRepository.getBooks()).thenAnswer(
      (_) async => [
        for (var i = 0; i < 30; i++) Book(bookUrl: 'u$i', name: '书籍$i'),
      ],
    );
    when(() => mockApi.bookGroupRepository.getBookGroups())
        .thenAnswer((_) async => []);
    when(() => mockApi.bookSourceRepository.getBookSources())
        .thenAnswer((_) async => []);
    when(() => mockApi.rssSourceRepository.getRssSources())
        .thenAnswer((_) async => []);
    // 首页页签数据源：阅读记录 + 每日时长（HomeTabScreen initState 拉取）
    when(() => mockApi.readRecordRepository)
        .thenReturn(MockReadRecordRepository());
    await tester.pumpWidget(
      ProviderScope(
        overrides: mergeTestOverrides([
          ...mockApi.overrides,
          if (mainPreferences != null)
            homeSettingsRepositoryProvider.overrideWithValue(mainPreferences),
        ]),
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  int navBarIndex(WidgetTester tester) =>
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

  MainPrefsNotifier preferences(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(HomeScreen)))
          .read(mainPrefsProvider.notifier);

  double currentPage(WidgetTester tester) =>
      tester.widget<PageView>(find.byType(PageView)).controller!.page!;

  AppHomeSettingsRepository repositoryFor(HomeSettingsStorage storage) {
    final service = AppSettingsService(
      storages: {SettingsStorageKind.preferences: storage},
    );
    addTearDown(() {
      final barrier = storage.readBarrier;
      if (barrier != null && !barrier.isCompleted) barrier.complete();
      unawaited(service.dispose());
    });
    return AppHomeSettingsRepository(service);
  }

  for (final entry in {
    'home': 0,
    'bookshelf': 1,
    'explore': 2,
    'rss': 3,
    'my': 4,
  }.entries) {
    testWidgets('启动默认页 ${entry.key} 正确，后续更改默认值不抢走当前页', (tester) async {
      await pumpHome(
        tester,
        MockRustApi(),
        preferences: {'defaultHomePage': entry.key},
      );
      expect(navBarIndex(tester), entry.value);
      expect(currentPage(tester), entry.value.toDouble());
      await preferences(tester)
          .setDefaultHomePage(entry.key == 'home' ? 'my' : 'home');
      await tester.pumpAndSettle();
      expect(navBarIndex(tester), entry.value);
      expect(currentPage(tester), entry.value.toDouble());
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('默认发现页已隐藏时回书架，重新启用后不补跳默认页', (tester) async {
    await pumpHome(
      tester,
      MockRustApi(),
      preferences: {'defaultHomePage': 'explore', 'showDiscovery': false},
    );
    expect(navBarIndex(tester), 1);
    expect(currentPage(tester), 1);
    await preferences(tester).setShowDiscovery(true);
    await tester.pumpAndSettle();
    expect(currentPage(tester), 1);
  });

  testWidgets('未知默认页回书架但不改写原偏好', (tester) async {
    await pumpHome(
      tester,
      MockRustApi(),
      preferences: {'defaultHomePage': 'unknown'},
    );
    expect(currentPage(tester), 1);
    expect(
      (await SharedPreferences.getInstance()).getString('defaultHomePage'),
      'unknown',
    );
  });

  testWidgets('初始化晚到时用户先切页再回书架，默认页不再接管', (tester) async {
    final barrier = Completer<void>();
    final storage = HomeSettingsStorage()
      ..values['defaultHomePage'] = 'my'
      ..readBarrier = barrier;
    await pumpHome(
      tester,
      MockRustApi(),
      mainPreferences: repositoryFor(storage),
    );
    await tester.tap(find.byType(NavigationDestination).at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(NavigationDestination).at(1));
    await tester.pumpAndSettle();
    barrier.complete();
    await tester.pumpAndSettle();
    expect(navBarIndex(tester), 1);
    expect(currentPage(tester), 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('仓储已预加载时仍应用默认页', (tester) async {
    final storage = HomeSettingsStorage()..values['defaultHomePage'] = 'my';
    final repository = repositoryFor(storage);
    await repository.load();
    await pumpHome(tester, MockRustApi(), mainPreferences: repository);
    expect(currentPage(tester), 4);
  });

  testWidgets('用户已开始滑动但尚未换页时，晚到默认页不能打断手势', (tester) async {
    final barrier = Completer<void>();
    final storage = HomeSettingsStorage()
      ..values['defaultHomePage'] = 'my'
      ..readBarrier = barrier;
    await pumpHome(
      tester,
      MockRustApi(),
      mainPreferences: repositoryFor(storage),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PageView)),
    );
    await gesture.moveBy(const Offset(-60, 0));
    await tester.pump();
    barrier.complete();
    await tester.pump();
    expect(currentPage(tester), lessThan(3));
    await gesture.moveBy(const Offset(-220, 0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(currentPage(tester), 2);
    expect(navBarIndex(tester), 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('点击导航经过中间位置，快速反向以最后目标为准', (tester) async {
    await pumpHome(tester, MockRustApi());
    await tester.tap(find.byType(NavigationDestination).at(4));
    await tester.pump();
    expect(currentPage(tester), 1);
    await tester.pump(const Duration(milliseconds: 70));
    expect(currentPage(tester), inExclusiveRange(1.0, 4.0));
    expect(navBarIndex(tester), 4);
    await tester.tap(find.byType(NavigationDestination).at(0));
    await tester.pumpAndSettle();
    expect(currentPage(tester), 0);
    expect(navBarIndex(tester), 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('导航动画中手势可接管，不被原点击目标拉回', (tester) async {
    await pumpHome(tester, MockRustApi());
    await tester.tap(find.byType(NavigationDestination).at(4));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    await tester.drag(find.byType(PageView), const Offset(350, 0));
    await tester.pumpAndSettle();
    expect(currentPage(tester), lessThan(4));
    expect(navBarIndex(tester), currentPage(tester).round());
    expect(tester.takeException(), isNull);
  });

  testWidgets('快速显隐与用户切页不会被旧帧回调改回去', (tester) async {
    await pumpHome(tester, MockRustApi());
    final notifier = preferences(tester);
    await tester.tap(find.byType(NavigationDestination).at(3));
    await tester.pumpAndSettle();
    final first = notifier.setShowDiscovery(false);
    final second = notifier.setShowDiscovery(true);
    final third = notifier.setShowRss(false);
    await tester.tap(find.byType(NavigationDestination).at(0));
    await Future.wait([first, second, third]);
    await tester.pumpAndSettle();
    expect(currentPage(tester), 0);
    expect(navBarIndex(tester), 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('隐藏当前页保存失败后恢复开关，导航保持有效且一致', (tester) async {
    final storage = HomeSettingsStorage();
    await pumpHome(
      tester,
      MockRustApi(),
      mainPreferences: repositoryFor(storage),
    );
    await tester.tap(find.byType(NavigationDestination).at(2));
    await tester.pumpAndSettle();
    final barrier = Completer<void>();
    storage.beforeWrite = (_, _) async {
      await barrier.future;
      throw StateError('保存失败');
    };
    final failure = expectLater(
      preferences(tester).setShowDiscovery(false),
      throwsStateError,
    );
    await tester.pumpAndSettle();
    expect(currentPage(tester), 1);
    barrier.complete();
    await failure;
    await tester.pumpAndSettle();
    expect(find.byType(NavigationDestination), findsNWidgets(5));
    expect(navBarIndex(tester), 1);
    expect(currentPage(tester), 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('恢复偏好后重定位当前页，但不重新应用默认首页', (tester) async {
    final storage = HomeSettingsStorage();
    await pumpHome(
      tester,
      MockRustApi(),
      mainPreferences: repositoryFor(storage),
    );
    await tester.tap(find.byType(NavigationDestination).at(4));
    await tester.pumpAndSettle();
    storage.values.addAll({
      'showDiscovery': false,
      'showRss': false,
      'defaultHomePage': 'home',
    });
    await preferences(tester).reload();
    await tester.pumpAndSettle();
    expect(currentPage(tester), 2);
    expect(navBarIndex(tester), 2);
  });

  testWidgets('侧栏与底栏切换时页签显隐仍定位同一逻辑页', (tester) async {
    await pumpHome(tester, MockRustApi());
    await tester.tap(find.byType(NavigationDestination).at(3));
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(800, 600);
    await tester.pumpAndSettle();
    await preferences(tester).setShowDiscovery(false);
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex,
      2,
    );
    expect(currentPage(tester), 2);
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(navBarIndex(tester), 2);
    expect(currentPage(tester), 2);
  });

  testWidgets('隐藏当前发现页后回书架，页面和底栏一致', (tester) async {
    await pumpHome(tester, MockRustApi());
    await tester.tap(find.byType(NavigationDestination).at(2));
    await tester.pumpAndSettle();
    await preferences(tester).setShowDiscovery(false);
    await tester.pumpAndSettle();
    expect(navBarIndex(tester), 1);
    expect(currentPage(tester), 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('隐藏订阅之前的发现页时保留订阅逻辑页', (tester) async {
    await pumpHome(tester, MockRustApi());
    await tester.tap(find.byType(NavigationDestination).at(3));
    await tester.pumpAndSettle();
    await preferences(tester).setShowDiscovery(false);
    await tester.pumpAndSettle();
    expect(navBarIndex(tester), 2);
    expect(currentPage(tester), 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('我的页连续隐藏发现和订阅后仍停留我的页', (tester) async {
    await pumpHome(tester, MockRustApi());
    await tester.tap(find.byType(NavigationDestination).at(4));
    await tester.pumpAndSettle();
    await preferences(tester).setShowDiscovery(false);
    await preferences(tester).setShowRss(false);
    await tester.pumpAndSettle();
    expect(navBarIndex(tester), 2);
    expect(currentPage(tester), 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('初始结构：五页签（首页/书架/发现/订阅/我的），默认落书架', (tester) async {
    await pumpHome(tester, MockRustApi());

    // [UI_SYNC_REFACTOR S1] 恢复 PageView 滑动切页（2026-09-05 拉参考源码
    // 核实 HorizontalPager userScrollEnabled=true，早前 IndexedStack 口径系误读；
    // 原版本就是 ViewPager 滑动）
    expect(find.byType(PageView), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    // 首页页签插入后书架恒为索引 1（默认主页=书架语义不变）
    expect(find.byType(NavigationDestination), findsNWidgets(5));
    expect(navBarIndex(tester), 1);
    // 书架页为当前展示页面
    expect(find.byType(BookshelfScreen), findsOneWidget);
  });

  testWidgets('首页页签：点击切入并渲染最近阅读/统计/目标表盘', (tester) async {
    await pumpHome(tester, MockRustApi());

    await tester.tap(find.byType(NavigationDestination).at(0));
    await tester.pumpAndSettle();

    expect(find.byType(HomeTabScreen), findsOneWidget);
    // 「首页」文本存在于底栏标签与页内大标题多处
    expect(find.text('首页'), findsWidgets);
    expect(find.text('累计阅读'), findsOneWidget);
    expect(find.text('阅读时长'), findsOneWidget);
    expect(find.text('今日阅读目标'), findsOneWidget);
    expect(navBarIndex(tester), 0);
  });

  testWidgets('横屏从首页选择书架分组会先切到书架', (tester) async {
    final api = MockRustApi();
    await pumpHome(tester, api);
    when(
      () => api.bookGroupRepository.getBookGroups(),
    ).thenAnswer((_) async => [const BookGroup(groupId: 8, groupName: '测试分组')]);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    );
    await container.read(bookshelfNotifierProvider.notifier).refresh();
    tester.view.physicalSize = const Size(800, 600);
    await tester.pumpAndSettle();
    final rail = find.byType(NavigationRail);
    expect(rail, findsOneWidget);
    await tester.tap(find.descendant(of: rail, matching: find.byTooltip('首页')));
    await tester.pumpAndSettle();
    expect(tester.widget<NavigationRail>(rail).selectedIndex, 0);
    await tester.longPress(find.byKey(const ValueKey('rail-bookshelf-groups')));
    await tester.pumpAndSettle();
    final item = find.descendant(
      of: find.byType(CheckboxMenuButton),
      matching: find.text('测试分组'),
    );
    await tester.tap(item);
    await tester.pumpAndSettle();
    expect(tester.widget<NavigationRail>(rail).selectedIndex, 1);
    expect(container.read(bookshelfNotifierProvider).selectedGroup?.groupId, 8);
    expect(tester.takeException(), isNull);
  });

  testWidgets('底栏切页到发现页，选中态同步（滑动切页）', (tester) async {
    await pumpHome(tester, MockRustApi());

    // 此处通过底栏定位发现页；真实滑动另有回归用例。
    await tester.tap(find.byType(NavigationDestination).at(2));
    await tester.pumpAndSettle();

    expect(find.byType(ExploreScreen), findsOneWidget);
    expect(navBarIndex(tester), 2);
  });

  testWidgets('点击底栏项过渡后显示目标页面', (tester) async {
    await pumpHome(tester, MockRustApi());

    await tester.tap(find.byType(NavigationDestination).at(4));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(navBarIndex(tester), 4);
  });

  testWidgets('返回键：非书架页先切回书架页', (tester) async {
    await pumpHome(tester, MockRustApi());

    // 先到「我的」页
    await tester.tap(find.byType(NavigationDestination).at(4));
    await tester.pumpAndSettle();
    expect(navBarIndex(tester), 4);

    await simulateBackButton(tester);
    await tester.pumpAndSettle();

    expect(navBarIndex(tester), 1);
    expect(find.text('再按一次退出程序'), findsNothing);
  });

  testWidgets('返回键：书架页首次按下弹出双击退出提示', (tester) async {
    await pumpHome(tester, MockRustApi());

    // 从首页切入书架页
    await tester.tap(find.byType(NavigationDestination).at(1));
    await tester.pumpAndSettle();

    await simulateBackButton(tester);
    await tester.pump();

    expect(find.text('再按一次退出程序'), findsOneWidget);
  });

  testWidgets('双击底栏书架项：列表回滚顶部（对标 gotoTop）', (tester) async {
    await pumpHome(tester, MockRustApi());

    // 从首页切入书架页
    await tester.tap(find.byType(NavigationDestination).at(1));
    await tester.pumpAndSettle();

    // [骨架对齐 2.0.260 | 台账 1-3] 书架头部 sliver 新增可滚动分组 TabBar，
    // CustomScrollView 下出现第二个（横向）Scrollable；此处只取纵向书列表
    // 滚动项（AxisDirection.down），横向 Tab 滚动项不参与回顶断言。
    final scrollable = find.descendant(
      of: find.byType(CustomScrollView),
      matching: find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      ),
    );

    // 先向下滚动一段距离
    await tester.drag(scrollable, const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(
      tester.state<ScrollableState>(scrollable).position.pixels,
      greaterThan(0),
    );

    // 300ms 内双击底栏书架项
    await tester.tap(find.byType(NavigationDestination).at(1));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byType(NavigationDestination).at(1));
    await tester.pumpAndSettle();

    expect(tester.state<ScrollableState>(scrollable).position.pixels, 0);
  });
}

/// 模拟系统返回键（触发 PopScope 回调）
Future<void> simulateBackButton(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
}
