import '../fixtures/app_test_api.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/routes.dart';
import 'package:flutter_legado/src/features/bookshelf/bookshelf.dart';

import '../mocks/mocks.dart';

/// 书架菜单保留背景内容，点击外部关闭，选择后进入原目标页面。
void main() {
  late MockRustApi mockApi;
  late ProviderContainer container;

  setUpAll(registerFallbacks);

  setUp(() {
    mockApi = MockRustApi();
  });

  /// 书架含一本「未读之书」
  const bookUnread = Book(
    name: '未读之书',
    bookUrl: 'book://shelf-menu',
    totalChapterNum: 100,
  );

  /// pump 书架页（桩路由占位），返回其 ProviderScope 容器
  Future<ProviderContainer> pumpShelf(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: mergeTestOverrides([...mockApi.overrides]),
        child: MaterialApp(
          home: const BookshelfScreen(),
          routes: {
            AppRoutes.bookInfo: (_) => const _StubPage(label: 'STUB_DETAIL'),
            AppRoutes.reader: (_) => const _StubPage(label: 'STUB_READER'),
            AppRoutes.remoteBooks: (_) => const _StubPage(label: 'STUB_REMOTE'),
          },
        ),
      ),
    );
    final context = tester.element(find.byType(BookshelfScreen));
    return ProviderScope.containerOf(context);
  }

  testWidgets('书架菜单打开、关闭与操作导航保持正常', (tester) async {
    SharedPreferences.setMockInitialValues({});
    when(() => mockApi.bookshelfRepository.getBooks())
        .thenAnswer((_) async => [bookUnread]);
    when(() => mockApi.bookGroupRepository.getBookGroups())
        .thenAnswer((_) async => []);

    container = await pumpShelf(tester);
    addTearDown(container.dispose);
    // Notifier build() 的 _loadSettings/_loadBooks/_loadGroups 落定
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(find.text('未读之书'), findsOneWidget, reason: '书架书籍条目应已加载');

    // 打开顶栏「⋮ 更多」菜单
    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(MenuItemButton), findsWidgets);

    // 书架内容仍可见（未被菜单遮住）
    expect(
      find.text('未读之书'),
      findsOneWidget,
      reason: '[P2-31] 打开菜单后，后方书架书籍仍应可见',
    );

    // 右侧浮卡菜单项可见
    expect(find.text('远程书籍'), findsOneWidget, reason: '菜单浮卡首项「远程书籍」应可见');

    // 点菜单外部，关闭后可再次展开并执行原操作。
    await tester.tapAt(const Offset(20, 560));
    await tester.pumpAndSettle();
    expect(find.text('远程书籍'), findsNothing);
    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('远程书籍'));
    await tester.pumpAndSettle();
    expect(find.text('STUB_REMOTE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

/// 桩页：占位（更多菜单 action 目标路由 / 详情页 / 阅读器），
/// 避免 push 到真实页面。
class _StubPage extends StatelessWidget {
  final String label;
  const _StubPage({required this.label});

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Text(label));
  }
}
