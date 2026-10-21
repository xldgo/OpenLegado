import '../fixtures/app_test_api.dart';

// AppScaffold 页壳测试（GLOBALCOMP B4）
//
// 覆盖四层证据：
// 1) 壳基本结构：topBar/body/bottomBar/FAB 各就各位、几何贴边正确；
// 2) 背景契约：backgroundColor 默认 null → 由 ThemeData.scaffoldBackgroundColor
//    供给（背景图透明壁纸策略 P1-8 依赖此项），显式传入时直通；
// 3) 同构等价：与裸 Scaffold 相同组合逐元素几何一致（迁移点行为等价证据），
//    且壳对未提供参数零改写（resizeToAvoidBottomInset 等保持 Scaffold 默认）；
// 4) 迁移屏等价：HomeScreen 经壳渲染后，壳内 Scaffold 参数与迁移前逐项一致
//    （appBar==null / bottomNavigationBar!=null / backgroundColor==null /
//    无 FAB），且结构（PageView + 五页签底栏）与迁移前一致。
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_legado/src/data/repositories/mock_read_record_repository.dart';

import 'package:flutter_legado/src/features/home/presentation/home_screen.dart';
import 'package:flutter_legado/src/widgets/app_scaffold.dart';
import 'package:flutter_legado/src/widgets/app_scroll_view.dart';
import 'package:flutter_legado/src/widgets/md3_fast_scroller.dart';
import 'package:flutter_legado/src/widgets/legado_app_bar.dart';
import 'package:flutter_legado/src/widgets/ui_settings_scope.dart';
import 'package:flutter_legado/src/domain/models/ui_settings.dart';
import 'package:flutter_legado/src/theme/app_theme.dart';
import 'package:flutter_legado/src/widgets/dynamic_search_app_bar.dart';

import '../mocks/mocks.dart';

void main() {
  setUpAll(registerFallbacks);

  testWidgets('快速滚动条共享控制器时只绘制和拖动自己的列表位置', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              for (var column = 0; column < 2; column++)
                Expanded(
                  child: Md3FastScroller(
                    controller: controller,
                    child: ListView.builder(
                      controller: controller,
                      itemCount: 100,
                      itemExtent: 50,
                      itemBuilder: (_, i) => Text('$column/$i'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.positions, hasLength(2));
    final first = find.byType(Md3FastScroller).first;
    final second = find.byType(Md3FastScroller).last;
    ScrollPosition position(Finder view) => tester
        .state<ScrollableState>(
          find.descendant(of: view, matching: find.byType(Scrollable)),
        )
        .position;
    final thumb = find.descendant(
      of: first,
      matching: find.byType(GestureDetector),
    );
    expect(thumb, findsOneWidget);
    await tester.drag(thumb, const Offset(0, 150));
    await tester.pumpAndSettle();
    expect(position(first).pixels, greaterThan(0));
    expect(position(second).pixels, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('独立正文沿用外部控制器，回顶信号更换后解除旧订阅', (tester) async {
    final controller = ScrollController();
    final first = ValueNotifier(0);
    final second = ValueNotifier(0);
    addTearDown(controller.dispose);
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    Future<void> mount(ValueNotifier<int> signal) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppScrollView(
              controller: controller,
              scrollTopSignal: signal,
              slivers: [
                SliverFixedExtentList.builder(
                  itemExtent: 50,
                  itemCount: 100,
                  itemBuilder: (_, i) => Text('项目$i'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await mount(first);
    controller.jumpTo(400);
    await tester.pump();
    await mount(second);
    expect(controller.offset, 400);
    first.value++;
    await tester.pumpAndSettle();
    expect(controller.offset, 400);
    second.value++;
    await tester.pumpAndSettle();
    expect(controller.offset, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(controller.hasClients, isFalse);
    controller.addListener(() {});
    first.value++;
    second.value++;
    expect(tester.takeException(), isNull);
  });

  for (final large in [false, true]) {
    testWidgets('带副标题的搜索栏保持标题坐标并按文字高度占位：大标题$large', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      var search = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: UiSettingsScope(
            settings: UiSettings(useFlexibleTopAppBar: large),
            child: StatefulBuilder(
              builder: (context, setState) => AppScaffold(
                topBar: DynamicSearchAppBar(
                  title: '发现',
                  subtitle: '当前分组',
                  searchController: controller,
                  searchHint: '筛选',
                  onChanged: (_) {},
                  expanded: search,
                  onExpandedChanged: (value) => setState(() => search = value),
                ),
                body: ListView.builder(
                  itemCount: 50,
                  itemExtent: 48,
                  itemBuilder: (_, i) => Text('内容$i'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final title = find
          .descendant(of: find.byType(AppBar), matching: find.text('发现'))
          .first;
      final subtitle = find
          .descendant(of: find.byType(AppBar), matching: find.text('当前分组'))
          .first;
      final titleRect = tester.getRect(title);
      final subtitleRect = tester.getRect(subtitle);
      if (large) {
        expect(titleRect.top, 64);
        expect(
          tester.getRect(find.byType(AppBar)).bottom - subtitleRect.bottom,
          8,
        );
      }
      await tester.tap(find.byTooltip('展开搜索'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.getRect(title), titleRect);
      expect(tester.getRect(subtitle), subtitleRect);
      await tester.pumpAndSettle();
      expect(tester.getRect(title), titleRect);
      await tester.tap(find.byTooltip('收起搜索'));
      await tester.pumpAndSettle();
      expect(tester.getRect(title), titleRect);
      expect(tester.takeException(), isNull);
    });
  }

  for (final withTabs in [false, true]) {
    testWidgets('根页顶栏在折叠边界显示标题且不残留标题带：页签$withTabs', (tester) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: CustomScrollView(
              controller: scroll,
              slivers: [
                LegadoTabRootHeaderSliver(
                  title: const Text('书架'),
                  large: true,
                  actions: [
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.search),
                    ),
                  ],
                  bottom: withTabs
                      ? const PreferredSize(
                          preferredSize: Size.fromHeight(56),
                          child: SizedBox(height: 56, child: Text('全部')),
                        )
                      : null,
                ),
                SliverFixedExtentList(
                  itemExtent: 56,
                  delegate: SliverChildBuilderDelegate(
                    (_, index) => Text('书籍$index'),
                    childCount: 60,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(AppBar)).height,
        104 + (withTabs ? 56 : 0),
      );
      // 用项目实际主题验证原生两种标题角色，避免只验证默认Material主题。
      final titleSizes = find
          .text('书架')
          .evaluate()
          .map((element) => DefaultTextStyle.of(element).style.fontSize);
      expect(titleSizes, containsAll([24.0, 18.0]));
      scroll.jumpTo(48);
      await tester.pumpAndSettle();
      final opacity = tester.widget<AnimatedOpacity>(
        find
            .ancestor(
              of: find.text('书架'),
              matching: find.byType(AnimatedOpacity),
            )
            .first,
      );
      expect(opacity.opacity, 1);
      expect(
        tester.getSize(find.byType(AppBar)).height,
        56 + (withTabs ? 56 : 0),
      );
      final toolbarTitle = find.descendant(
        of: find.byType(AnimatedOpacity),
        matching: find.text('书架'),
      );
      expect(
        DefaultTextStyle.of(tester.element(toolbarTitle)).style.fontSize,
        18,
      );
      final icon = find.byIcon(Icons.search);
      expect(
        tester.getCenter(toolbarTitle).dy,
        closeTo(tester.getCenter(icon).dy, 1),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    '页签列表切换后仍与共用顶栏协调滚动',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultTabController(
            length: 2,
            child: AppScaffold(
              topBar: const LegadoAppBar(
                title: Text('引擎管理'),
                bottom: TabBar(
                  tabs: [
                    Tab(text: '音色'),
                    Tab(text: '引擎'),
                  ],
                ),
              ),
              body: TabBarView(
                children: [
                  for (var tab = 0; tab < 2; tab++)
                    ListView.builder(
                      key: PageStorageKey('list-$tab'),
                      itemCount: 50,
                      itemExtent: 56,
                      itemBuilder: (_, index) => Text('项目$tab/$index'),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).first, const Offset(0, -250));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Tab, '引擎'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).last, const Offset(0, -250));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.windows,
    }),
  );

  testWidgets('专用页明确保留标准顶栏与自身控制器', (tester) async {
    final fallback = ScrollController();
    addTearDown(fallback.dispose);
    ScrollController? connected;
    await tester.pumpWidget(
      MaterialApp(
        home: AppScaffold(
          collapsibleTopBar: false,
          topBar: const LegadoAppBar(title: Text('专用编辑器')),
          body: AppScrollBody(
            controller: fallback,
            builder: (context, controller) {
              connected = controller;
              return ListView(
                controller: controller,
                children: const [Text('编辑内容')],
              );
            },
          ),
        ),
      ),
    );
    expect(find.byType(NestedScrollView), findsNothing);
    expect(connected, same(fallback));
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).appBar,
      isA<LegadoAppBar>(),
    );
  });

  testWidgets('共用大标题随正文折叠，开关保留正文和滚动控制器', (tester) async {
    final setting = ValueNotifier<bool>(true);
    final fallback = ScrollController();
    addTearDown(setting.dispose);
    addTearDown(fallback.dispose);
    ScrollController? connected;
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<bool>(
          valueListenable: setting,
          builder: (context, large, _) => UiSettingsScope(
            settings: UiSettings(useFlexibleTopAppBar: large),
            child: AppScaffold(
              topBar: const LegadoAppBar(title: Text('通用设置')),
              body: AppScrollBody(
                controller: fallback,
                builder: (context, controller) {
                  connected = controller;
                  return ListView.builder(
                    controller: controller,
                    itemExtent: 56,
                    itemCount: 100,
                    itemBuilder: (_, index) => Text('设置项目$index'),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final nested = tester.state<NestedScrollViewState>(
      find.byType(NestedScrollView),
    );
    final expandedExtent = nested.outerController.position.maxScrollExtent;
    expect(connected, same(nested.innerController));
    expect(nested.outerController.position.maxScrollExtent, greaterThan(0));
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(nested.outerController.offset, greaterThan(0));
    expect(connected!.offset, greaterThan(0));
    final collapsedTitle = find.text('通用设置');
    final titleOpacity = tester.widget<AnimatedOpacity>(
      find
          .ancestor(of: collapsedTitle, matching: find.byType(AnimatedOpacity))
          .first,
    );
    expect(titleOpacity.opacity, 1, reason: '正文已滚动时固定工具栏必须显示标题');
    expect(tester.getSize(find.byType(AppBar)).height, kToolbarHeight);
    final inner = connected;
    setting.value = false;
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(NestedScrollView)), same(nested));
    expect(connected, same(inner));
    expect(
      nested.outerController.position.maxScrollExtent,
      lessThan(expandedExtent),
    );
    expect(connected!.offset, greaterThan(0));
    setting.value = true;
    await tester.pumpAndSettle();
    expect(nested.outerController.position.maxScrollExtent, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('正文延伸只改变底栏后的可绘制范围，默认保留原占位', (tester) async {
    for (final extend in [false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          home: AppScaffold(
            extendBody: extend,
            bottomBar: const SizedBox(height: 80),
            body: const SizedBox.expand(key: ValueKey('extended-body')),
          ),
        ),
      );
      final body = tester.getRect(find.byKey(const ValueKey('extended-body')));
      final scaffold = tester.getRect(find.byType(Scaffold));
      expect(body.bottom, scaffold.bottom - (extend ? 0 : 80));
    }
  });

  testWidgets('壳基本结构：topBar/body/bottomBar/FAB 各就各位', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppScaffold(
          topBar: AppBar(title: const Text('壳标题')),
          body: const Center(child: Text('壳主体')),
          bottomBar: NavigationBar(
            selectedIndex: 0,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_rounded), label: '甲'),
              NavigationDestination(
                icon: Icon(Icons.person_rounded),
                label: '乙',
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {},
            child: const Icon(Icons.add),
          ),
        ),
      ),
    );

    // 壳下仍是标准 Scaffold（既有 find.byType(Scaffold) 断言全兼容）
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('壳标题'), findsOneWidget);
    expect(find.text('壳主体'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);

    final scaffold = tester.getRect(find.byType(Scaffold));
    final appBar = tester.getRect(find.byType(AppBar));
    final navBar = tester.getRect(find.byType(NavigationBar));
    // 顶栏贴顶、底栏贴底（测试画布无系统 inset）
    expect(appBar.top, scaffold.top);
    expect(navBar.bottom, scaffold.bottom);
    // FAB 默认 endFloat：位于底栏之上、屏内右侧
    final fab = tester.getRect(find.byType(FloatingActionButton));
    expect(fab.right, lessThanOrEqualTo(scaffold.right));
    expect(fab.bottom, lessThanOrEqualTo(navBar.top));
  });

  testWidgets('背景契约：默认跟随主题（不硬编码），显式传入直通', (tester) async {
    const themeBg = Color(0xFF123456);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(scaffoldBackgroundColor: themeBg),
        home: AppScaffold(body: const SizedBox.expand()),
      ),
    );

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    // 不写死背景色：保留「设置背景图 → scaffoldBackgroundColor 透明露壁纸」
    expect(scaffold.backgroundColor, isNull);
    final materials = tester.widgetList<Material>(
      find.descendant(
        of: find.byType(Scaffold),
        matching: find.byType(Material),
      ),
    );
    expect(materials.any((m) => m.color == themeBg), isTrue);

    const override = Color(0xFFABCDEF);
    await tester.pumpWidget(
      MaterialApp(
        home: AppScaffold(
          backgroundColor: override,
          body: const SizedBox.expand(),
        ),
      ),
    );
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      override,
    );
  });

  testWidgets('同构等价：与裸 Scaffold 相同组合逐元素几何一致', (tester) async {
    Widget compose(bool shell) {
      final bar = AppBar(title: const Text('等价标题'));
      final body = Container(
        key: const ValueKey('body'),
        color: const Color(0x22000000),
      );
      const bottom = SizedBox(
        key: ValueKey('bottom'),
        height: 48,
        child: ColoredBox(color: Colors.blue),
      );
      final fab = FloatingActionButton(
        key: const ValueKey('fab'),
        onPressed: () {},
        child: const Icon(Icons.add),
      );
      if (shell) {
        return AppScaffold(
          topBar: bar,
          body: body,
          bottomBar: bottom,
          floatingActionButton: fab,
        );
      }
      return Scaffold(
        appBar: bar,
        body: body,
        bottomNavigationBar: bottom,
        floatingActionButton: fab,
      );
    }

    Map<String, Rect> capture() => {
      'scaffold': tester.getRect(find.byType(Scaffold)),
      'bar': tester.getRect(find.byType(AppBar)),
      'body': tester.getRect(find.byKey(const ValueKey('body'))),
      'bottom': tester.getRect(find.byKey(const ValueKey('bottom'))),
      'fab': tester.getRect(find.byKey(const ValueKey('fab'))),
    };

    await tester.pumpWidget(MaterialApp(home: compose(false)));
    final raw = capture();
    await tester.pumpWidget(MaterialApp(home: compose(true)));
    final shell = capture();

    expect(shell, raw);

    // 参数零改写：未提供项保持 Scaffold 默认（resizeToAvoidBottomInset 为
    // null 即「未设置」，Scaffold 内部按 true 处理；位置为 null 即默认位）
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, isNull);
    expect(scaffold.resizeToAvoidBottomInset, isNull);
    expect(scaffold.floatingActionButtonLocation, isNull);
  });

  testWidgets('迁移屏 HomeScreen：经壳渲染且结构与迁移前逐参数一致', (tester) async {
    // 本用例核对手机底栏；宽窗口会按现有设置切换侧栏。
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final mockApi = MockRustApi();
    when(() => mockApi.bookshelfRepository.getBooks())
        .thenAnswer((_) async => []);
    when(() => mockApi.bookGroupRepository.getBookGroups())
        .thenAnswer((_) async => []);
    when(() => mockApi.bookSourceRepository.getBookSources())
        .thenAnswer((_) async => []);
    when(() => mockApi.rssSourceRepository.getRssSources())
        .thenAnswer((_) async => []);
    when(() => mockApi.readRecordRepository)
        .thenReturn(MockReadRecordRepository());

    await tester.pumpWidget(
      ProviderScope(
        overrides: mergeTestOverrides([...mockApi.overrides]),
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // 迁移点 1：页壳已换用 AppScaffold（PageView 预载相邻 Tab，书架页亦是
    // 壳，故树中可出现多个；取外层=HomeScreen 自身页壳）
    expect(find.byType(AppScaffold), findsWidgets);
    final homeShell = find.byType(AppScaffold).first;

    // 迁移点 2：壳内 Scaffold 参数与迁移前逐项一致（5 页签容器）
    final scaffold = tester.widget<Scaffold>(
      find.descendant(of: homeShell, matching: find.byType(Scaffold)).first,
    );
    expect(scaffold.appBar, isNull); // 迁移前无 appBar
    expect(scaffold.bottomNavigationBar, isNotNull); // 底栏三形态装配
    expect(scaffold.backgroundColor, isNull); // 跟随主题/壁纸策略
    expect(scaffold.floatingActionButton, isNull);
    expect(scaffold.resizeToAvoidBottomInset, isNull); // 零改写

    // 迁移点 3：结构与迁移前一致（PageView 滑动切页 + 五页签底栏）
    expect(
      find.descendant(
        of: find.byType(HomeScreen),
        matching: find.byType(PageView),
      ),
      findsWidgets,
    );
    expect(find.byType(NavigationBar), findsWidgets);
    expect(find.byType(NavigationDestination), findsNWidgets(5));
  });
}
