import '../fixtures/routing_test_app.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_legado/src/features/bookshelf/bookshelf.dart';
import 'package:flutter_legado/src/app/routing/route_names.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/widgets/app_scroll_view.dart';

import '../fixtures/app_test_api.dart';
import '../mocks/mocks.dart';

/// 挂载生产书架；目标路由占位仅用于验证实际导航。— Codex + UI
void main() {
  setUpAll(registerFallbacks);
  Future<MockRustApi> showShelf(
    WidgetTester tester, {
    int bookCount = 0,
    bool grid = false,
    ValueNotifier<int>? scrollTopSignal,
  }) async {
    SharedPreferences.setMockInitialValues({'bookshelf_layout': grid});
    final api = MockRustApi();
    when(() => api.bookshelfRepository.getBooks()).thenAnswer(
      (_) async => [
        for (var i = 0; i < bookCount; i++) Book(bookUrl: 'u$i', name: '书籍$i'),
      ],
    );
    when(() => api.bookGroupRepository.getBookGroups())
        .thenAnswer((_) async => []);
    await tester.pumpWidget(
      ProviderScope(
        overrides: mergeTestOverrides(api.overrides),
        child: RoutingTestApp(
          home: BookshelfScreen(scrollTopSignal: scrollTopSignal),
          routes: {
            AppRoutes.search: (_) => const Scaffold(body: Text('搜索目标页')),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    return api;
  }

  testWidgets('真实书架空态保留搜索和更多入口', (tester) async {
    await showShelf(tester);
    expect(find.byType(BookshelfScreen), findsOneWidget);
    expect(find.byTooltip('搜索'), findsOneWidget);
    expect(find.byTooltip('更多'), findsOneWidget);
    expect(find.text('书架还空着，先去搜索书籍或从发现里添加吧！'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('真实书架搜索入口执行导航，返回仍保留空态', (tester) async {
    await showShelf(tester);
    await tester.tap(find.byTooltip('搜索'));
    await tester.pumpAndSettle();
    expect(find.text('搜索目标页'), findsOneWidget);
    Navigator.of(tester.element(find.text('搜索目标页'))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(BookshelfScreen), findsOneWidget);
    expect(find.text('书架还空着，先去搜索书籍或从发现里添加吧！'), findsOneWidget);
  });

  for (final bookCount in [0, 1]) {
    for (final grid in [false, true]) {
      testWidgets('短书架独立折叠、回顶和刷新：$bookCount本/网格$grid', (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final signal = ValueNotifier(0);
        addTearDown(signal.dispose);
        final api = await showShelf(
          tester,
          bookCount: bookCount,
          grid: grid,
          scrollTopSignal: signal,
        );
        final shell = tester.state<NestedScrollViewState>(
          find.byType(NestedScrollView),
        );
        final body = find.descendant(
          of: find.byType(AppScrollView),
          matching: find.byType(CustomScrollView),
        );
        expect(shell.innerController.position.maxScrollExtent, 0);
        expect(shell.outerController.position.maxScrollExtent, greaterThan(0));

        await tester.drag(body, const Offset(0, -200));
        await tester.pumpAndSettle();
        expect(
          shell.outerController.offset,
          shell.outerController.position.maxScrollExtent,
        );
        expect(shell.innerController.offset, 0);

        signal.value++;
        await tester.pumpAndSettle();
        expect(shell.outerController.offset, 0);
        expect(shell.innerController.offset, 0);

        clearInteractions(api.bookshelfRepository);
        await tester.drag(body, const Offset(0, 350));
        await tester.pumpAndSettle();
        verify(() => api.bookshelfRepository.getBooks()).called(1);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
