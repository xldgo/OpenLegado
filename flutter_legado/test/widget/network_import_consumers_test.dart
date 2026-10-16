import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/domain/models/http_response.dart';
import 'package:flutter_legado/src/features/bookshelf/bookshelf.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/providers/network_provider.dart';
import 'package:flutter_legado/src/providers/providers.dart';
import 'package:flutter_legado/src/widgets/app_menu.dart';

import '../mocks/mocks.dart';

void main() {
  setUpAll(registerFallbacks);
  late MockRustApi api;
  late NetworkServiceMock network;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    api = MockRustApi();
    network = NetworkServiceMock();
    when(() => api.bookshelfRepository.getBooks()).thenAnswer((_) async => []);
    when(() => api.bookGroupRepository.getBookGroups())
        .thenAnswer((_) async => []);
    when(() => api.bookSourceRepository.getEnabledBookSources())
        .thenAnswer((_) async => []);
  });

  Future<void> import(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookApiProvider.overrideWithValue(api),
          networkServiceProvider.overrideWithValue(network),
        ],
        child: const MaterialApp(home: BookshelfScreen()),
      ),
    );
    await tester.pumpAndSettle();
    tester
        .widget<AppMenuButton<String>>(find.byType(AppMenuButton<String>))
        .onSelected!('import_list');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'https://example.test/books',
    );
    await tester.tap(find.widgetWithText(FilledButton, '导入'));
    await tester.pumpAndSettle();
  }

  testWidgets('书单URL导入解析HTTP正文，并通过窄网络Provider取回数据', (tester) async {
    when(() => network.httpGet('https://example.test/books')).thenAnswer(
      (_) async => const HttpTextResponse(
        statusCode: 200,
        body: '[{"name":"测试小说","author":"作者"}]',
        url: 'https://cdn.test/books',
      ),
    );
    when(() => api.searchService.preciseSearch('测试小说', '作者', sourceUrls: null))
        .thenAnswer(
          (_) async =>
              const SearchBook(bookUrl: 'book', name: '测试小说', author: '作者'),
        );
    when(() => api.bookshelfRepository.addBook(any()))
        .thenAnswer((call) async => call.positionalArguments.single as Book);
    await import(tester);
    verify(() => network.httpGet('https://example.test/books')).called(1);
    final added =
        verify(() => api.bookshelfRepository.addBook(captureAny()))
                .captured
                .single
            as Book;
    expect(added.name, '测试小说');
    expect(added.bookUrl, 'book');
    expect(find.textContaining('无效的书单'), findsNothing);
    verifyNever(() => api.networkService.httpGet(any()));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('书单HTTP失败不继续搜索或写入书架，即使正文是有效列表', (tester) async {
    when(() => network.httpGet('https://example.test/books')).thenAnswer(
      (_) async =>
          const HttpTextResponse(statusCode: 503, body: '[{"name":"测试小说"}]'),
    );
    await import(tester);
    expect(find.textContaining('HTTP 503'), findsOneWidget);
    verifyNever(
      () => api.searchService.preciseSearch(
        any(),
        any(),
        sourceUrls: any(named: 'sourceUrls'),
      ),
    );
    verifyNever(() => api.bookshelfRepository.addBook(any()));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
