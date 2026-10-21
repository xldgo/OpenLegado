import '../fixtures/app_test_api.dart';

import 'package:flutter_legado/src/domain/models/search_batch.dart';
import 'package:flutter_legado/src/features/search/search.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/theme/app_theme.dart';
import 'package:flutter_legado/src/widgets/bottom_sheet_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../mocks/mocks.dart';

void main() {
  late MockRustApi api;
  late ProviderContainer container;
  const sources = [
    BookSource(
      bookSourceName: '甲书源',
      bookSourceUrl: 'https://alpha.test',
      bookSourceGroup: '玄幻',
    ),
    BookSource(
      bookSourceName: '乙书源',
      bookSourceUrl: 'https://beta.test',
      bookSourceGroup: '玄幻',
    ),
    BookSource(
      bookSourceName: '丙书源',
      bookSourceUrl: 'https://gamma.test',
      bookSourceGroup: '科幻',
    ),
  ];
  setUpAll(registerFallbacks);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    api = MockRustApi();
    when(
      () => api.searchHistoryRepository.getSearchHistory(
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => []);
    when(() => api.searchHistoryRepository.addSearchKeyword(any(), any()))
        .thenAnswer((_) async {});
    when(() => api.searchService.cancelSearch()).thenAnswer((_) async {});
    when(() => api.configRepository.getConfig(any()))
        .thenAnswer((_) async => null);
    when(() => api.configRepository.setConfig(any(), any()))
        .thenAnswer((_) async {});
    when(() => api.bookSourceRepository.getEnabledBookSources())
        .thenAnswer((_) async => sources);
    when(
      () => api.searchService.searchMultiStream(
        any(),
        sourceUrls: any(named: 'sourceUrls'),
        page: any(named: 'page'),
      ),
    ).thenAnswer(
      (_) => Stream.value(
        SearchBatch(
          books: const [
            SearchResult(
              book: Book(
                bookUrl: 'https://alpha.test/book',
                name: '测试',
                author: '作者',
                origin: 'https://alpha.test',
              ),
            ),
          ],
          sourceUrl: 'https://alpha.test',
          finishedCount: 1,
          totalCount: 1,
          isLast: true,
          hasMore: false,
        ),
      ),
    );
    container = ProviderContainer(overrides: mergeTestOverrides(api.overrides));
    addTearDown(container.dispose);
  });

  Future<void> pump(
    WidgetTester tester, {
    List<String>? urls,
    String? query,
    bool dark = false,
  }) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: dark ? AppTheme.dark : AppTheme.light,
          home: SearchScreen(initialQuery: query, initialSourceUrls: urls),
        ),
      ),
    );
    await tester.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
  }

  Finder inSheet(Finder finder) =>
      find.descendant(of: find.byType(AppBottomSheet), matching: finder);
  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.byTooltip('搜索范围'));
    await tester.pumpAndSettle();
    expect(find.byType(AppBottomSheet), findsOneWidget);
  }

  Future<void> tap(WidgetTester tester, String text) async {
    await tester.tap(inSheet(find.text(text)));
    await tester.pumpAndSettle();
  }

  CheckboxListTile row(WidgetTester tester, String url) =>
      tester.widget<CheckboxListTile>(find.byKey(ValueKey(url)));
  SearchState state() => container.read(searchNotifierProvider);

  testWidgets('书源多选确认后仅重搜一次，完整传递集合且重新打开仍勾选', (tester) async {
    await pump(tester, query: '测试');
    await open(tester);
    await tap(tester, '书源');
    await tap(tester, '甲书源');
    await tap(tester, '乙书源');
    expect(state().selectedSourceUrls, isEmpty);
    expect(row(tester, sources[0].bookSourceUrl).value, isTrue);
    expect(row(tester, sources[1].bookSourceUrl).value, isTrue);
    await tap(tester, '确定');
    expect(state().selectedSourceUrls, {
      'https://alpha.test',
      'https://beta.test',
    });
    verify(
      () => api.searchService.searchMultiStream(
        '测试',
        sourceUrls: ['https://alpha.test', 'https://beta.test'],
        page: 1,
      ),
    ).called(1);
    await open(tester);
    expect(row(tester, sources[0].bookSourceUrl).value, isTrue);
    expect(row(tester, sources[1].bookSourceUrl).value, isTrue);
    await tap(tester, '取消');
    expect(tester.takeException(), isNull);
  });

  testWidgets('切换页签不清空选择，取消或遮罩关闭不应用草稿', (tester) async {
    await pump(tester, urls: ['https://alpha.test', 'https://beta.test']);
    await open(tester);
    await tap(tester, '分组');
    await tap(tester, '确定');
    expect(state().selectedSourceUrls, {
      'https://alpha.test',
      'https://beta.test',
    });
    for (final cancel in [true, false]) {
      await open(tester);
      await tap(tester, '分组');
      await tap(tester, '科幻');
      if (cancel) {
        await tap(tester, '取消');
      } else {
        final top = tester.getRect(find.byType(BottomSheet)).top;
        await tester.tapAt(Offset(10, top / 2));
        await tester.pumpAndSettle();
      }
      expect(state().selectedSourceUrls, {
        'https://alpha.test',
        'https://beta.test',
      });
      expect(state().selectedGroups, isEmpty);
    }
    verifyNever(
      () => api.searchService.searchMultiStream(
        any(),
        sourceUrls: any(named: 'sourceUrls'),
        page: any(named: 'page'),
      ),
    );
  });

  testWidgets('按名称、URL和分组筛选，隐藏选项不丢失勾选', (tester) async {
    await pump(tester);
    await open(tester);
    await tap(tester, '书源');
    await tap(tester, '甲书源');
    final input = inSheet(find.byType(TextField));
    for (final keyword in ['乙书源', 'BETA.TEST', '科幻']) {
      await tester.enterText(input, keyword);
      await tester.pumpAndSettle();
      expect(
        inSheet(
          find.byKey(
            ValueKey(
              keyword == '科幻' ? 'https://gamma.test' : 'https://beta.test',
            ),
          ),
        ),
        findsOneWidget,
      );
      expect(inSheet(find.text('甲书源')), findsNothing);
    }
    await tester.enterText(input, 'beta.test');
    await tester.pumpAndSettle();
    await tap(tester, '乙书源');
    await tester.enterText(input, '');
    await tester.pumpAndSettle();
    expect(row(tester, sources[0].bookSourceUrl).value, isTrue);
    expect(row(tester, sources[1].bookSourceUrl).value, isTrue);
    await tap(tester, '确定');
    expect(state().selectedSourceUrls.length, 2);
  });

  testWidgets('分组与书源互斥，全部书源只在确认后清空范围', (tester) async {
    await pump(tester, urls: ['https://alpha.test', 'https://beta.test']);
    await open(tester);
    await tap(tester, '分组');
    await tap(tester, '玄幻');
    await tap(tester, '科幻');
    await tap(tester, '确定');
    expect(state().selectedGroups, {'玄幻', '科幻'});
    expect(state().selectedSourceUrls, isEmpty);
    await open(tester);
    await tap(tester, '全部书源');
    await tap(tester, '取消');
    expect(state().selectedGroups.length, 2);
    await open(tester);
    await tap(tester, '全部书源');
    await tap(tester, '确定');
    expect(state().hasFilter, isFalse);
  });

  testWidgets('深色长列表独立滚动，标题居中且键盘不遮住确认操作', (tester) async {
    final many = List.generate(
      30,
      (i) => BookSource(
        bookSourceName: '书源$i',
        bookSourceUrl: 'https://$i.test',
        bookSourceGroup: '分组$i',
      ),
    );
    when(() => api.bookSourceRepository.getEnabledBookSources())
        .thenAnswer((_) async => many);
    await pump(tester, dark: true);
    await open(tester);
    final title = inSheet(find.text('搜索范围'));
    final header = tester.getRect(title);
    expect(header.center.dx, closeTo(180, .01));
    final list = inSheet(find.byType(ListView));
    await tester.drag(list, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(tester.getRect(title), header);
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    await tester.pumpAndSettle();
    expect(
      tester.getRect(inSheet(find.text('确定'))).bottom,
      lessThanOrEqualTo(400),
    );
    expect(inSheet(find.byType(TextField)), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tap(tester, '取消');
  });
}
