import '../fixtures/app_test_api.dart';

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/features/explore/presentation/explore_screen.dart';
import 'package:flutter_legado/src/features/rss/presentation/rss_screen.dart';
import 'package:flutter_legado/src/widgets/app_scroll_view.dart';
import 'package:flutter_legado/src/widgets/md3_fast_scroller.dart';

import '../mocks/mocks.dart';

/// 报障复现：订阅页（有数据）+ 发现页（有数据）真实渲染抓异常
///
/// 背景：用户报订阅页报错、发现页顶部文字看不清；logcat Dart 层无报错，
/// 需在测试环境复设有数据状态的渲染，确认有无 ErrorWidget/断言。
void main() {
  setUpAll(registerFallbacks);

  Widget wrap(Widget child, MockRustApi mockApi) {
    return ProviderScope(
      overrides: mergeTestOverrides([...mockApi.overrides]),
      child: MaterialApp(home: child),
    );
  }

  testWidgets('发现加载骨架显示后切换真实列表不产生控制器异常', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final api = MockRustApi();
    final loaded = Completer<List<BookSource>>();
    when(() => api.bookSourceRepository.getBookSources())
        .thenAnswer((_) => loaded.future);
    await tester.pumpWidget(wrap(const ExploreScreen(), api));
    await tester.pump(const Duration(milliseconds: 100));
    loaded.complete([
      for (var i = 0; i < 30; i++)
        BookSource(
          bookSourceUrl: 'demo://$i',
          bookSourceName: '发现源$i',
          enabledExplore: true,
          exploreUrl: 'https://example.test/$i',
        ),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('发现源0'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final scroller = find.byType(Md3FastScroller);
    final thumb = find
        .descendant(of: scroller, matching: find.byType(GestureDetector))
        .last;
    expect(
      tester.widget<GestureDetector>(thumb).onVerticalDragUpdate,
      isNotNull,
    );
    final shell = tester.state<NestedScrollViewState>(
      find.byType(NestedScrollView),
    );
    final before = shell.innerController.offset;
    await tester.drag(thumb, const Offset(0, 160));
    await tester.pumpAndSettle();
    expect(shell.innerController.offset, greaterThan(before));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('订阅页有数据渲染无异常', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final mockApi = MockRustApi();
    when(() => mockApi.rssSourceRepository.getRssSources()).thenAnswer(
      (_) async => const [
        RssSource(sourceUrl: 'u1', sourceName: '源一'),
        RssSource(sourceUrl: 'u2', sourceName: '源二', sourceGroup: '分组A'),
      ],
    );
    when(() => mockApi.rssSourceRepository.importRssSources(any()))
        .thenAnswer((_) async => 0);
    await tester.pumpWidget(wrap(const RssScreen(), mockApi));
    await tester.pumpAndSettle();

    expect(find.byType(ErrorWidget), findsNothing);
    expect(find.text('源一'), findsOneWidget);
    expect(find.text('源二'), findsOneWidget);
    expect(find.text('规则订阅'), findsOneWidget);
    final shell = tester.state<NestedScrollViewState>(
      find.byType(NestedScrollView),
    );
    expect(shell.innerController.position.maxScrollExtent, 0);
    expect(shell.outerController.position.maxScrollExtent, greaterThan(0));
    await tester.drag(find.byType(AppScrollView), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(
      shell.outerController.offset,
      shell.outerController.position.maxScrollExtent,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('发现页有数据渲染无异常', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final mockApi = MockRustApi();
    when(() => mockApi.bookSourceRepository.getBookSources()).thenAnswer(
      (_) async => const [
        BookSource(
          bookSourceUrl: 'u1',
          bookSourceName: '书源一',
          enabledExplore: true,
          exploreUrl: 'https://a.test/x',
        ),
        BookSource(
          bookSourceUrl: 'u2',
          bookSourceName: '书源二',
          bookSourceGroup: '分组A',
          enabledExplore: true,
          exploreUrl: 'https://b.test/y',
        ),
      ],
    );
    await tester.pumpWidget(wrap(const ExploreScreen(), mockApi));
    await tester.pumpAndSettle();

    expect(find.byType(ErrorWidget), findsNothing);
    expect(find.text('书源一'), findsOneWidget);
    expect(find.text('书源二'), findsOneWidget);
    // 当前分组显示在共用顶栏副标题，展开与折叠原型会同时构建。
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('全部')),
      findsWidgets,
    );
  });
}
