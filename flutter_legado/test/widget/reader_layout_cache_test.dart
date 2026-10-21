@Tags(['native'])
library;

import 'dart:async';

import '../fixtures/app_test_api.dart';
import '../mocks/reading_fixture.dart';
import '../helpers/native_reader_layout.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_legado/src/features/reader/application/reader_notifier.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/widgets/reader/reader_page_view.dart';
import 'package:flutter_legado/src/widgets/reader/reader_text_content.dart';
import 'package:flutter_legado/src/widgets/reader/turn/reader_turn_view.dart';
import 'package:flutter_legado/src/data/services/chapter_content_service.dart';
import 'package:flutter_legado/src/platform/display/display_corners.dart';
import 'package:flutter_legado/src/widgets/reader/reader_footer_geometry.dart';
import 'package:flutter_legado/src/providers/chapter_content_provider.dart';

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
  void replaceBook() => state = state.copyWith(
    currentBook: const Book(bookUrl: 'replacement-book'),
  );
}

class _ReaderWithPageRequest extends _Reader {
  @override
  // 保证第35页需要多批排版，不让该场景依赖默认行距与边距。
  ReaderState build() => super.build().copyWith(
    currentChapterPos: 35,
    chapterContent: '${sources[0]}\n${sources[0]}',
  );
}

class _Content extends Fake implements ChapterContentService {
  final requests = <(String, int)>[];

  @override
  Future<String> read(String bookUrl, int index) async {
    requests.add((bookUrl, index));
    return sources[index];
  }
}

class _DeferredContent extends _Content {
  final first = Completer<String>();

  @override
  Future<String> read(String bookUrl, int index) {
    if (requests.isEmpty) {
      requests.add((bookUrl, index));
      return first.future;
    }
    return super.read(bookUrl, index);
  }
}

void main() {
  setUpNativeReaderLayout();
  testWidgets('圆角更新只使翻页快照失效，不重新分页或改变原文范围', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final key = GlobalKey<ReaderPageViewState>();
    final container = ProviderContainer(
      overrides: mergeTestOverrides([
        ..._Api().overrides,
        readerNotifierProvider.overrideWith(_Reader.new),
      ]),
    );
    addTearDown(container.dispose);
    Future<void> show(DisplayCorners corners) async {
      await pumpNativeReaderLayout(
        tester,
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            builder: nativeReaderLayoutBuilder,
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 320,
                  height: 500,
                  child: ReaderFooterGeometry(
                    corners: corners,
                    child: ReaderPageView(
                      key: key,
                      paragraphSpacing: 8,
                      selectText: false,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await settleNativeReaderLayout(tester);
    }

    await show(const DisplayCorners(size: Size(320, 500)));
    final measurements = key.currentState!.layoutMeasurements;
    final range = key.currentState!.currentSourceRange;
    final before = tester
        .widget<ReaderTurnView>(find.byType(ReaderTurnView))
        .paintRevision;
    const rounded = DisplayCorners(
      size: Size(320, 500),
      bottomLeft: DisplayCorner(center: Offset(50, 450), radius: 50),
      bottomRight: DisplayCorner(center: Offset(270, 450), radius: 50),
    );
    await show(rounded);
    final after = tester
        .widget<ReaderTurnView>(find.byType(ReaderTurnView))
        .paintRevision;
    expect(after, greaterThan(before));
    expect(key.currentState!.layoutMeasurements, measurements);
    expect(key.currentState!.currentSourceRange, range);
    await show(
      DisplayCorners(
        size: rounded.size,
        bottomLeft: rounded.bottomLeft,
        bottomRight: rounded.bottomRight,
      ),
    );
    expect(
      tester.widget<ReaderTurnView>(find.byType(ReaderTurnView)).paintRevision,
      after,
    );
    expect(key.currentState!.layoutMeasurements, measurements);
    expect(tester.takeException(), isNull);
  });
  for (final replaceBook in [true, false]) {
    testWidgets('${replaceBook ? '同章换书' : '视口重排'}后丢弃迟到预载，不覆盖新预览或增加测量', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final content = _DeferredContent();
      final key = GlobalKey<ReaderPageViewState>();
      final container = ProviderContainer(
        overrides: mergeTestOverrides([
          ..._Api().overrides,
          readerNotifierProvider.overrideWith(_Reader.new),
          chapterContentServiceProvider.overrideWithValue(content),
        ]),
      );
      addTearDown(container.dispose);
      Future<void> pump(double width) => pumpNativeReaderLayout(
        tester,
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            builder: nativeReaderLayoutBuilder,
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
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await pump(320);
      expect(content.requests, [('layout-fixture', 1)]);
      if (replaceBook) {
        (container.read(readerNotifierProvider.notifier) as _Reader)
            .replaceBook();
      }
      await pump(replaceBook ? 320 : 420);
      expect(content.requests, [
        ('layout-fixture', 1),
        (replaceBook ? 'replacement-book' : 'layout-fixture', 1),
      ]);
      final preview = tester
          .widget<ReaderTurnView>(find.byType(ReaderTurnView))
          .chapterNextPage;
      expect(preview, isNotNull);
      final measurements = key.currentState!.layoutMeasurements;
      content.first.complete(sources[2]);
      await settleNativeReaderLayout(tester);
      expect(
        tester
            .widget<ReaderTurnView>(find.byType(ReaderTurnView))
            .chapterNextPage,
        same(preview),
      );
      expect(key.currentState!.layoutMeasurements, measurements);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('阅读器退出后迟到预载不再读取Provider或构建预览', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final content = _DeferredContent();
    await pumpNativeReaderLayout(
      tester,
      ProviderScope(
        overrides: mergeTestOverrides([
          ..._Api().overrides,
          readerNotifierProvider.overrideWith(_Reader.new),
          chapterContentServiceProvider.overrideWithValue(content),
        ]),
        child: MaterialApp(
          builder: nativeReaderLayoutBuilder,
          home: const Scaffold(
            body: ReaderPageView(paragraphSpacing: 8, selectText: false),
          ),
        ),
      ),
    );
    expect(content.requests, [('layout-fixture', 1)]);
    await tester.pumpWidget(const SizedBox.shrink());
    content.first.complete(sources[2]);
    await settleNativeReaderLayout(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('边界预览通过注入的正文服务取得后续章并完成布局', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final content = _Content();
    await pumpNativeReaderLayout(
      tester,
      ProviderScope(
        overrides: mergeTestOverrides([
          ..._Api().overrides,
          readerNotifierProvider.overrideWith(_Reader.new),
          chapterContentServiceProvider.overrideWithValue(content),
        ]),
        child: MaterialApp(
          builder: nativeReaderLayoutBuilder,
          home: const Scaffold(
            body: SizedBox(
              width: 320,
              height: 500,
              child: ReaderPageView(paragraphSpacing: 8),
            ),
          ),
        ),
      ),
    );
    await settleNativeReaderLayout(tester);
    expect(content.requests, [('layout-fixture', 1)]);
    expect(
      tester
          .widget<ReaderTurnView>(find.byType(ReaderTurnView))
          .chapterNextPage,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('当前布局中的显式跳页等待分批页面就绪，再派生原文锚点', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final key = GlobalKey<ReaderPageViewState>();
    await pumpNativeReaderLayout(
      tester,
      ProviderScope(
        overrides: mergeTestOverrides([
          ..._Api().overrides,
          readerNotifierProvider.overrideWith(_ReaderWithPageRequest.new),
        ]),
        child: MaterialApp(
          builder: nativeReaderLayoutBuilder,
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
    await settleNativeReaderLayout(tester);
    expect(key.currentState!.currentSourceRange.$1, greaterThan(0));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ReaderPageView)),
    );
    expect(key.currentState!.pageCount, greaterThan(35));
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
      overrides: mergeTestOverrides([
        ..._Api().overrides,
        readerNotifierProvider.overrideWith(_Reader.new),
      ]),
    );
    addTearDown(container.dispose);
    Future<void> pump(double width) async {
      await pumpNativeReaderLayout(
        tester,
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            builder: nativeReaderLayoutBuilder,
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
      await settleNativeReaderLayout(tester);
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
    await settleNativeReaderLayout(tester);
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
    await settleNativeReaderLayout(tester);
    expect(key.currentState!.layoutMeasurements, measurements);
    final hits = key.currentState!.layoutCacheHits;
    notifier.chapter(1);
    await tester.pump();
    expect(key.currentState!.layoutCacheHits, greaterThan(hits));
    await settleNativeReaderLayout(tester);
    expect(
      tester
          .widget<ReaderTextContent>(find.byType(ReaderTextContent).first)
          .pageInfo
          .sourceText,
      sources[1],
    );
    notifier.mode(PageTurnMode.scroll);
    await settleNativeReaderLayout(tester);
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -900),
    );
    await settleNativeReaderLayout(tester);
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
