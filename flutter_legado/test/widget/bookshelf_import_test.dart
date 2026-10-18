import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/domain/errors/app_exception.dart';
import 'package:flutter_legado/src/features/bookshelf/bookshelf_screen.dart';
import 'package:flutter_legado/src/l10n/app_localization.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/widgets/app_menu.dart';

import '../fixtures/app_test_api.dart';
import '../mocks/mocks.dart';

/// 使用实际页面、Provider和controller验证接线，不以替身界面代替书架。— Codex + UI
void main() {
  late MockRustApi api;
  late List<Book> books;

  setUpAll(registerFallbacks);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    api = MockRustApi();
    books = [];
    when(() => api.bookshelfRepository.getBooks())
        .thenAnswer((_) async => List.of(books));
    when(() => api.bookGroupRepository.getBookGroups())
        .thenAnswer((_) async => []);
    when(() => api.bookSourceRepository.getEnabledBookSources())
        .thenAnswer((_) async => []);
    when(() => api.bookshelfRepository.addBook(any())).thenAnswer((call) async {
      final book = call.positionalArguments.single as Book;
      books.add(book);
      return book;
    });
  });

  Future<AppLocalizations> openMenu(WidgetTester tester, String action) async {
    await tester.binding.setSurfaceSize(const Size(800, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: api.overrides,
        child: const MaterialApp(home: BookshelfScreen()),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = tester.element(find.byType(BookshelfScreen)).l10n;
    await tester.tap(find.byType(AppMenuButton<String>).first);
    await tester.pumpAndSettle();
    final label = action == 'import' ? l10n.importBookList : l10n.addBookUrl;
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
    return l10n;
  }

  testWidgets('书单成功导入后刷新实际书架并显示原统计文案', (tester) async {
    when(
      () => api.searchService.preciseSearch('导入的新书', '作者', sourceUrls: null),
    ).thenAnswer(
      (_) async =>
          const SearchBook(name: '导入的新书', author: '作者', bookUrl: 'book://new'),
    );
    final l10n = await openMenu(tester, 'import');
    clearInteractions(api.bookshelfRepository);
    await tester.enterText(
      find.byType(TextField),
      '[{"name":"导入的新书","author":"作者"}]',
    );
    await tester.tap(find.widgetWithText(FilledButton, l10n.importAction));
    await tester.pumpAndSettle();
    expect(find.text('导入的新书'), findsOneWidget);
    expect(find.text(l10n.bookListImportFinished(1, 0, 0)), findsOneWidget);
    verify(() => api.bookshelfRepository.getBooks()).called(1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('格式无效只提示错误，不刷新书架或搜索', (tester) async {
    final l10n = await openMenu(tester, 'import');
    clearInteractions(api.bookshelfRepository);
    await tester.enterText(find.byType(TextField), '{}');
    await tester.tap(find.widgetWithText(FilledButton, l10n.importAction));
    await tester.pumpAndSettle();
    expect(find.text(l10n.invalidBookList), findsOneWidget);
    verifyZeroInteractions(api.bookshelfRepository);
    verifyZeroInteractions(api.searchService);
    expect(tester.takeException(), isNull);
  });

  testWidgets('拉取失败显示领域错误消息且不刷新书架', (tester) async {
    when(() => api.networkService.httpGet('https://list.test'))
        .thenThrow(const AppException('书单连接失败'));
    final l10n = await openMenu(tester, 'import');
    clearInteractions(api.bookshelfRepository);
    await tester.enterText(find.byType(TextField), 'https://list.test');
    await tester.tap(find.widgetWithText(FilledButton, l10n.importAction));
    await tester.pumpAndSettle();
    expect(find.text(l10n.bookListFetchFailed('书单连接失败')), findsOneWidget);
    verifyZeroInteractions(api.bookshelfRepository);
    expect(tester.takeException(), isNull);
  });

  testWidgets('网址输入保留分隔、去空白和备用名，完成后刷新并统计去重', (tester) async {
    final l10n = await openMenu(tester, 'url');
    clearInteractions(api.bookshelfRepository);
    await tester.enterText(
      find.byType(TextField).at(0),
      ' https://new.test/1 ; https://new.test/1,\nhttps://new.test/2 ',
    );
    await tester.enterText(find.byType(TextField).at(1), ' 备用书名 ');
    await tester.tap(find.widgetWithText(FilledButton, l10n.confirm));
    await tester.pumpAndSettle();
    expect(books.map((b) => b.bookUrl), [
      'https://new.test/1',
      'https://new.test/2',
    ]);
    expect(books.every((b) => b.name == '备用书名'), isTrue);
    expect(find.text(l10n.addBookUrlFinished(2, 1, 0)), findsOneWidget);
    verify(() => api.bookshelfRepository.getBooks()).called(1);
    expect(tester.takeException(), isNull);
  });
}
