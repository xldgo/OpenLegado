import 'package:flutter_legado/src/app/bootstrap/application_dependencies.dart';
import 'package:flutter_legado/src/domain/contracts/content_search_service.dart';
import 'package:flutter_legado/src/features/search/search_content_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures/app_test_api.dart';
import '../mocks/mocks.dart';

class _Matching extends Mock implements ContentSearchService {}

void main() {
  setUpAll(registerFallbacks);
  testWidgets('正则结果消费已计算区间，摘要不重跑缺失上下文的正则', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final api = MockRustApi();
    final matching = _Matching();
    when(
      () => api.searchHistoryRepository.getSearchHistory(
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => []);
    when(() => api.searchHistoryRepository.addSearchKeyword(any(), any()))
        .thenAnswer((_) async {});
    final snippet = '…${'a' * 30}甲${'b' * 30}…';
    const query = '(?<=a{40})甲';
    when(
      () => matching.search(
        bookUrl: 'book',
        query: query,
        useRegex: true,
        useReplace: false,
        scope: ContentSearchScope.network,
        currentChapterIndex: any(named: 'currentChapterIndex'),
      ),
    ).thenAnswer(
      (_) => Stream.value(
        ContentSearchBatch(
          chapterIndex: 0,
          chapterTitle: '第一章',
          scanned: 1,
          total: 1,
          hits: [
            ContentSearchHit(
              sourceStart: 40,
              sourceEnd: 41,
              snippet: snippet,
              highlightStart: 31,
              highlightEnd: 32,
            ),
          ],
        ),
      ),
    );
    final container = ProviderContainer(
      overrides: mergeTestOverrides([
        ...api.overrides,
        contentSearchServiceProvider.overrideWithValue(matching),
      ]),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: SearchContentScreen(bookUrl: 'book', bookName: '书'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('搜索选项'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('正则'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), query);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('第一章'), findsOneWidget);
    final result = tester.widget<Text>(
      find.byWidgetPredicate(
        (w) => w is Text && w.textSpan?.toPlainText() == snippet,
      ),
    );
    final parts = (result.textSpan! as TextSpan).children!.cast<TextSpan>();
    expect(parts.map((s) => s.text), ['…${'a' * 30}', '甲', '${'b' * 30}…']);
    expect(parts.where((s) => s.style != null).map((s) => s.text), ['甲']);
    verify(
      () => matching.search(
        bookUrl: 'book',
        query: query,
        useRegex: true,
        useReplace: false,
        scope: ContentSearchScope.network,
        currentChapterIndex: any(named: 'currentChapterIndex'),
      ),
    ).called(1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
