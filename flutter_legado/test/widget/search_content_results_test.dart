import 'package:flutter_legado/src/app/bootstrap/application_dependencies.dart';
import 'package:flutter_legado/src/domain/contracts/content_search_service.dart';
import 'package:flutter_legado/src/features/search/search_content_screen.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures/app_test_api.dart';
import '../mocks/mocks.dart';

class _Matching extends Mock implements ContentSearchService {}

class _Matcher extends Mock implements ContentSearchMatcher {}

void main() {
  setUpAll(registerFallbacks);
  testWidgets('正则结果消费已计算区间，摘要不重跑缺失上下文的正则', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final api = MockRustApi();
    final matching = _Matching();
    final matcher = _Matcher();
    when(
      () => api.searchHistoryRepository.getSearchHistory(
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => []);
    when(() => api.searchHistoryRepository.addSearchKeyword(any(), any()))
        .thenAnswer((_) async {});
    when(() => api.readingRepository.getChapters('book')).thenAnswer(
      (_) async => [
        const BookChapter(url: 'c', bookUrl: 'book', index: 0, title: '第一章'),
      ],
    );
    final content = '${'a' * 40}甲${'b' * 40}';
    final snippet = '…${'a' * 30}甲${'b' * 30}…';
    when(() => api.readingRepository.getChapterContentRaw('book', 0))
        .thenAnswer((_) async => content);
    const query = '(?<=a{40})甲';
    when(() => matching.open(query, useRegex: true))
        .thenAnswer((_) async => matcher);
    when(() => matcher.search(content)).thenAnswer(
      (_) async => [
        ContentSearchHit(
          sourceStart: 40,
          sourceEnd: 41,
          snippet: snippet,
          highlightStart: 31,
          highlightEnd: 32,
        ),
      ],
    );
    when(matcher.close).thenReturn(null);
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
    verify(() => matching.open(query, useRegex: true)).called(1);
    verify(matcher.close).called(1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
