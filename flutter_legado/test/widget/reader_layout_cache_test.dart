import '../mocks/reading_fixture.dart';
import '../helpers/reader_layout_host.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_legado/src/providers/providers.dart';
import 'package:flutter_legado/src/providers/reader/reader_notifier.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/services/mock_book_api.dart';
import 'package:flutter_legado/src/widgets/reader/reader_page_view.dart';
import 'package:flutter_legado/src/widgets/reader/reader_text_content.dart';
import 'package:flutter_legado/src/widgets/reader/turn/reader_turn_view.dart';

final sources = List.generate(
  3,
  (chapter) => List.generate(
    80,
    (i) => '第$chapter章第$i段正文。${'测试阅读布局缓存与分批排版。' * 3}',
  ).join('\n'),
);

class _Api extends MockBookApi {
  late final _fixtureReading = TestReadingRepository(
    delegate: super.readingRepository,
    getChapterContentFull: _readingGetChapterContentFull,
  );
  @override
  TestReadingRepository get readingRepository => _fixtureReading;

  Future<String> _readingGetChapterContentFull(
    String bookUrl,
    int index,
  ) async => sources[index];
}

class _Reader extends ReaderNotifier {
  @override
  ReaderState build() => ReaderState(
    currentBook: const Book(bookUrl: 'layout-fixture'),
    chapterContent: sources[0],
    chapters: const [
      BookChapter(title: '第零章', index: 0, url: 'chapter0'),
      BookChapter(title: '第一章', index: 1, url: 'chapter1'),
      BookChapter(title: '第二章', index: 2, url: 'chapter2'),
    ],
    pageTurnMode: PageTurnMode.none,
  );
  void chapter(int index) {
    updatePosition(0);
    state = state.copyWith(
      currentChapterIndex: index,
      currentChapterPos: 0,
      chapterContent: sources[index],
    );
  }

  void mode(PageTurnMode value) => state = state.copyWith(pageTurnMode: value);
  void color() => state = state.copyWith(backgroundColor: Colors.black);
}

class _ReaderWithPageRequest extends _Reader {
  @override
  ReaderState build() => super.build().copyWith(currentChapterPos: 35);
}

void main() {
  testWidgets('当前布局中的显式跳页等待分批页面就绪，再派生原文锚点', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final key = GlobalKey<ReaderPageViewState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          readerNotifierProvider.overrideWith(_ReaderWithPageRequest.new),
          bookApiProvider.overrideWithValue(_Api()),
        ],
        child: MaterialApp(
          builder: readerLayoutTestBuilder,
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 500,
              child: ReaderPageView(key: key, paragraphSpacing: 8),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(key.currentState!.currentSourceRange.$1, greaterThan(0));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ReaderPageView)),
    );
    expect(container.read(readerNotifierProvider).currentChapterPos, 35);
    expect(
      container.read(readerNotifierProvider.notifier).currentSourceOffset,
      key.currentState!.currentSourceRange.$1,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('相邻章完整布局命中，配色不重排，滚动重排保持原文位置', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final key = GlobalKey<ReaderPageViewState>();
    final container = ProviderContainer(
      overrides: [
        readerNotifierProvider.overrideWith(_Reader.new),
        bookApiProvider.overrideWithValue(_Api()),
      ],
    );
    addTearDown(container.dispose);
    Future<void> pump(double width) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            builder: readerLayoutTestBuilder,
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: width,
                  height: 500,
                  child: ReaderPageView(
                    key: key,
                    paragraphSpacing: 8,
                    selectText: false,
                    contentInsets: const EdgeInsets.fromLTRB(12, 40, 12, 20),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pump(320);
    expect(key.currentState!.layoutComplete, isTrue);
    final measurements = key.currentState!.layoutMeasurements;
    final notifier = container.read(readerNotifierProvider.notifier) as _Reader;
    final preview = tester
        .widget<ReaderTurnView>(find.byType(ReaderTurnView))
        .chapterNextPage;
    expect(preview, isNotNull);
    notifier.toggleControls();
    await tester.pumpAndSettle();
    expect(
      identical(
        preview,
        tester
            .widget<ReaderTurnView>(find.byType(ReaderTurnView))
            .chapterNextPage,
      ),
      isTrue,
    );
    expect(key.currentState!.layoutMeasurements, measurements);
    notifier.color();
    await tester.pumpAndSettle();
    expect(key.currentState!.layoutMeasurements, measurements);
    final hits = key.currentState!.layoutCacheHits;
    notifier.chapter(1);
    await tester.pump();
    expect(key.currentState!.layoutCacheHits, greaterThan(hits));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ReaderTextContent>(find.byType(ReaderTextContent).first)
          .pageInfo
          .sourceText,
      sources[1],
    );
    notifier.mode(PageTurnMode.scroll);
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -900),
    );
    await tester.pumpAndSettle();
    final anchor = notifier.currentSourceOffset!;
    expect(anchor, greaterThan(0));
    await pump(420);
    expect(notifier.currentSourceOffset, anchor);
    expect(key.currentState!.currentSourceRange.$1, lessThanOrEqualTo(anchor));
    expect(key.currentState!.currentSourceRange.$2, greaterThan(anchor));
    await pump(20);
    expect(find.text('阅读区域太小，请扩大窗口或减小页边距'), findsOneWidget);
    await pump(420);
    expect(find.text('阅读区域太小，请扩大窗口或减小页边距'), findsNothing);
    expect(notifier.currentSourceOffset, anchor);
    expect(tester.takeException(), isNull);
  });
}
