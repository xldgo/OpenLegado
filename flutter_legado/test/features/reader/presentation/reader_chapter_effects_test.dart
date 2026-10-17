import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/domain/models/review.dart';
import 'package:flutter_legado/src/features/reader/application/reader_notifier.dart';
import 'package:flutter_legado/src/features/reader/presentation/reader_screen.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/widgets/reader/reader_page_view.dart';
import 'package:flutter_legado/src/widgets/reader/review_column.dart';
import 'package:flutter_legado/src/widgets/reader/review_detail_sheet.dart';

import '../../../fixtures/app_test_api.dart';
import '../../../helpers/reader_layout_host.dart';
import '../../../mocks/mocks.dart';

void main() {
  setUpAll(registerFallbacks);

  testWidgets('实际阅读页按章更新段评，点击使用该章查询参数并打开详情', (tester) async {
    SharedPreferences.setMockInitialValues({'enableReadRecord': false});
    const book = Book(
      bookUrl: 'https://book/1',
      name: '段评小说',
      origin: 'https://source/1',
    );
    const chapters = [
      BookChapter(url: 'https://chapter/0', title: '第一章', index: 0),
      BookChapter(url: 'https://chapter/1', title: '第二章', index: 1),
      BookChapter(url: 'https://chapter/2', title: '第三章', index: 2),
    ];
    final api = MockRustApi();
    when(() => api.readingRepository.getChapters(book.bookUrl))
        .thenAnswer((_) async => chapters);
    when(() => api.readingRepository.getChapterContentFull(book.bookUrl, any()))
        .thenAnswer((_) async => '第一段小说正文。\n第二段小说正文。');
    when(
      () => api.readingRepository.updateReadingProgress(
        bookUrl: any(named: 'bookUrl'),
        chapterIndex: any(named: 'chapterIndex'),
        chapterPos: any(named: 'chapterPos'),
      ),
    ).thenAnswer((_) async {});
    when(() => api.bookSourceRepository.getBookSources()).thenAnswer(
      (_) async => [
        const BookSource(bookSourceUrl: 'https://source/1', mainJs: 'review'),
      ],
    );
    final loadedChapters = <String>[];
    when(() => api.reviewService.reviewGetSummary(any(), any())).thenAnswer((
      call,
    ) async {
      final request = call.positionalArguments[1] as Map<String, dynamic>;
      final chapterUrl = request['chapterUrl'] as String;
      loadedChapters.add(chapterUrl);
      final index = chapters.indexWhere((chapter) => chapter.url == chapterUrl);
      return ReviewSummary(
        counts: {1: index == 0 ? 4 : 7},
        keys: {1: '第$index章段评'},
      );
    });
    when(() => api.reviewService.reviewGetDetail(any(), any(), any()))
        .thenAnswer((_) async => ReviewPage(items: []));
    final container = ProviderContainer(
      overrides: mergeTestOverrides([...api.overrides]),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          builder: readerLayoutTestBuilder,
          home: const ReaderScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final reader = container.read(readerNotifierProvider.notifier);
    await reader.openBook(book);
    await tester.pumpAndSettle();
    expect(loadedChapters, [chapters[0].url]);
    expect(
      tester.widget<ReaderPageView>(find.byType(ReaderPageView)).reviewCounts,
      {1: 4},
    );
    final badge = find
        .byWidgetPredicate(
          (widget) => widget is ReviewColumnBadge && widget.count == 4,
        )
        .hitTestable();
    expect(badge, findsOneWidget);
    await tester.tap(badge);
    await tester.pumpAndSettle();
    final detail = tester.widget<ReviewDetailSheet>(
      find.byType(ReviewDetailSheet),
    );
    expect(detail.chapterUrl, chapters[0].url);
    expect(detail.paragraphData, '第0章段评');
    expect(detail.totalCount, 4);
    Navigator.of(tester.element(find.byType(ReviewDetailSheet))).pop();
    await tester.pumpAndSettle();
    await reader.goToChapter(1);
    await tester.pumpAndSettle();
    expect(loadedChapters, [chapters[0].url, chapters[1].url]);
    expect(
      tester.widget<ReaderPageView>(find.byType(ReaderPageView)).reviewCounts,
      {1: 7},
    );
    expect(
      find
          .byWidgetPredicate(
            (widget) => widget is ReviewColumnBadge && widget.count == 4,
          )
          .hitTestable(),
      findsNothing,
    );
    expect(
      find
          .byWidgetPredicate(
            (widget) => widget is ReviewColumnBadge && widget.count == 7,
          )
          .hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
