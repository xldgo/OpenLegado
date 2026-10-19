import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_legado/src/features/bookshelf/bookshelf.dart';
import 'package:flutter_legado/src/app/routing/route_names.dart';

import '../fixtures/app_test_api.dart';
import '../mocks/mocks.dart';

/// 挂载生产书架；目标路由占位仅用于验证实际导航。— Codex + UI
void main() {
  setUpAll(registerFallbacks);
  Future<void> showShelf(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final api = MockRustApi();
    when(() => api.bookshelfRepository.getBooks()).thenAnswer((_) async => []);
    when(() => api.bookGroupRepository.getBookGroups())
        .thenAnswer((_) async => []);
    await tester.pumpWidget(
      ProviderScope(
        overrides: mergeTestOverrides(api.overrides),
        child: MaterialApp(
          home: const BookshelfScreen(),
          routes: {
            AppRoutes.search: (_) => const Scaffold(body: Text('搜索目标页')),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
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
}
