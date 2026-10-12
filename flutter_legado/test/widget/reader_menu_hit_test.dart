import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/providers/providers.dart';
import 'package:flutter_legado/src/providers/reader/reader_notifier.dart';
import 'package:flutter_legado/src/routes.dart';
import 'package:flutter_legado/src/screens/reader_screen.dart';
import 'package:flutter_legado/src/services/mock_book_api.dart';
import 'package:flutter_legado/src/widgets/reader/reader_menu_panel.dart';
import 'package:flutter_legado/src/widgets/reader/reader_page_view.dart';

class _Reader extends ReaderNotifier {
  final ReaderState? initialState;
  _Reader([this.initialState]);

  int seekCalls = 0;
  ReaderState get value => state;

  @override
  ReaderState build() =>
      initialState ??
      const ReaderState(
        currentBook: Book(
          bookUrl: 'loc_book/menu.txt',
          name: '菜单点击测试',
          origin: BookType.localTag,
        ),
        chapters: [
          BookChapter(title: '第一章', index: 0),
          BookChapter(title: '第二章', index: 1),
          BookChapter(title: '第三章', index: 2),
        ],
        currentChapterIndex: 1,
        showControls: true,
      );

  @override
  Future<void> goToChapter(int index) async {
    seekCalls++;
    state = state.copyWith(currentChapterIndex: index);
  }
}

class _Hits {
  int bodyPointers = 0;
  int bodyTaps = 0;
  int bodyDrags = 0;
  int bodyLongPresses = 0;
  int ancestorTaps = 0;
  int catalogTaps = 0;
}

class _ScreenReader extends _Reader {
  final PageTurnMode mode;
  _ScreenReader([this.mode = PageTurnMode.none]);

  @override
  ReaderState build() => super.build().copyWith(
    chapterContent: List.filled(60, '这是用于验证菜单遮挡与正文翻页的测试段落。').join('\n'),
    currentChapterPos: 1,
    pageTurnMode: mode,
  );
}

Future<(_Reader, _Hits)> _pumpMenu(
  WidgetTester tester, {
  ReaderState? initialState,
  RouteFactory? onGenerateRoute,
}) async {
  SharedPreferences.setMockInitialValues({});
  final hits = _Hits();
  final container = ProviderContainer(
    overrides: [
      readerNotifierProvider.overrideWith(() => _Reader(initialState)),
      bookApiProvider.overrideWithValue(MockBookApi()),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        onGenerateRoute: onGenerateRoute,
        home: Scaffold(
          // 同时覆盖祖先点击识别和翻页组件使用的原始指针事件。
          body: GestureDetector(
            onTapUp: (_) => hits.ancestorTaps++,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (_) => hits.bodyPointers++,
                    onPointerMove: (_) => hits.bodyPointers++,
                    onPointerUp: (_) => hits.bodyPointers++,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => hits.bodyTaps++,
                      onPanUpdate: (_) => hits.bodyDrags++,
                      onLongPress: () => hits.bodyLongPresses++,
                    ),
                  ),
                ),
                Consumer(
                  builder: (context, ref, _) => ReaderMenuPanel(
                    visible: ref.watch(readerNotifierProvider).showControls,
                    onBack: () {},
                    onAddBookmark: () {},
                    onOpenCatalog: () => hits.catalogTaps++,
                    onOpenSettings: () {},
                    onOpenAdvancedConfig: () {},
                    onOpenContentSearch: () {},
                    onReadAloud: () {},
                    onToggleAutoPage: () {},
                    onOpenReplaceRules: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (container.read(readerNotifierProvider.notifier) as _Reader, hits);
}

void _expectNoBodyEvents(_Hits hits) {
  expect(hits.bodyPointers, 0);
  expect(hits.bodyDrags, 0);
  _expectNoBodyActions(hits);
}

void _expectNoBodyActions(_Hits hits) {
  expect(hits.bodyTaps, 0);
  expect(hits.bodyLongPresses, 0);
  expect(hits.ancestorTaps, 0);
}

Future<ProviderContainer> _pumpReader(
  WidgetTester tester, {
  PageTurnMode mode = PageTurnMode.none,
}) async {
  SharedPreferences.setMockInitialValues({});
  final container = ProviderContainer(
    overrides: [
      readerNotifierProvider.overrideWith(() => _ScreenReader(mode)),
      bookApiProvider.overrideWithValue(MockBookApi()),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: ReaderScreen()),
    ),
  );
  await tester.pumpAndSettle();
  // 菜单手势从章内第二页开始，避免配置重排将旧初始页码归零。
  if (mode != PageTurnMode.scroll) {
    tester.state<ReaderPageViewState>(find.byType(ReaderPageView)).goToPage(1);
    await tester.pumpAndSettle();
  }
  return container;
}

void main() {
  testWidgets('更多弹出菜单打开时，第一次正文点击只关闭弹出菜单', (tester) async {
    final (reader, hits) = await _pumpMenu(tester);
    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    expect(find.text('添加书签'), findsOneWidget);

    await tester.tapAt(const Offset(400, 300));
    await tester.pumpAndSettle();
    expect(find.text('添加书签'), findsNothing);
    expect(reader.value.showControls, isTrue);
    _expectNoBodyEvents(hits);

    await tester.tapAt(const Offset(400, 300));
    await tester.pumpAndSettle();
    expect(reader.value.showControls, isFalse);
    _expectNoBodyActions(hits);
  });

  testWidgets('关闭更多菜单的拖动不会同时关闭阅读菜单或翻页', (tester) async {
    final (reader, hits) = await _pumpMenu(tester);
    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    await tester.dragFrom(const Offset(400, 300), const Offset(-280, 0));
    await tester.pumpAndSettle();
    expect(find.text('添加书签'), findsNothing);
    expect(reader.value.showControls, isTrue);
    _expectNoBodyEvents(hits);

    await tester.dragFrom(const Offset(400, 300), const Offset(-280, 0));
    await tester.pumpAndSettle();
    expect(reader.value.showControls, isFalse);
    expect(hits.bodyDrags, greaterThan(0));
  });

  testWidgets('系统返回只关闭更多菜单，下一次正文点击仍可收起阅读菜单', (tester) async {
    final (reader, hits) = await _pumpMenu(tester);
    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('添加书签'), findsNothing);
    expect(reader.value.showControls, isTrue);
    await tester.tapAt(const Offset(400, 300));
    await tester.pumpAndSettle();
    expect(reader.value.showControls, isFalse);
    _expectNoBodyActions(hits);
  });

  testWidgets('外部关闭阅读菜单后重新打开，不残留弹出菜单的输入拦截', (tester) async {
    final (reader, hits) = await _pumpMenu(tester);
    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    reader.hideControls();
    await tester.pumpAndSettle();
    reader.toggleControls();
    await tester.pumpAndSettle();
    expect(find.text('添加书签'), findsNothing);
    await tester.tapAt(const Offset(400, 300));
    await tester.pumpAndSettle();
    expect(reader.value.showControls, isFalse);
    _expectNoBodyActions(hits);
  });

  for (final x in [8.0, 400.0, 792.0]) {
    testWidgets('菜单外正文 x=$x 点击只收起菜单，不触发正文点击', (tester) async {
      final (reader, hits) = await _pumpMenu(tester);
      await tester.tapAt(Offset(x, 300));
      await tester.pump();
      expect(reader.value.showControls, isFalse);
      expect(reader.value.currentChapterIndex, 1);
      _expectNoBodyActions(hits);
    });
  }

  testWidgets('顶栏书名和底栏留白消费点击，不关闭菜单或触发正文', (tester) async {
    final (reader, hits) = await _pumpMenu(tester);
    await tester.tap(find.text('菜单点击测试'));
    await tester.tapAt(Offset(2, tester.getCenter(find.byType(Slider)).dy));
    await tester.pump();
    expect(reader.value.showControls, isTrue);
    _expectNoBodyEvents(hits);
  });

  testWidgets('菜单按钮和进度滑条仍能操作，拖动不传给正文翻页', (tester) async {
    final (reader, hits) = await _pumpMenu(tester);
    await tester.tap(find.text('目录'));
    await tester.drag(find.byType(Slider), const Offset(180, 0));
    await tester.pumpAndSettle();
    expect(hits.catalogTaps, 1);
    expect(reader.seekCalls, greaterThan(0));
    expect(reader.value.showControls, isTrue);
    _expectNoBodyEvents(hits);
  });

  for (final direction in [
    const Offset(-300, 0),
    const Offset(300, 0),
    const Offset(0, -180),
    const Offset(0, 180),
  ]) {
    testWidgets('菜单外滑动 $direction 收起菜单，同时传给正文', (tester) async {
      final (reader, hits) = await _pumpMenu(tester);
      await tester.dragFrom(const Offset(400, 300), direction);
      await tester.pumpAndSettle();
      expect(reader.value.showControls, isFalse);
      expect(hits.bodyPointers, greaterThan(0));
      expect(hits.bodyDrags, greaterThan(0));
      _expectNoBodyActions(hits);
    });
  }

  testWidgets('菜单外按下即收起，长按不会选中正文', (tester) async {
    final (reader, hits) = await _pumpMenu(tester);
    final gesture = await tester.startGesture(const Offset(400, 300));
    await tester.pump();
    expect(reader.value.showControls, isFalse);
    await tester.pump(const Duration(milliseconds: 700));
    await gesture.up();
    await tester.pump();
    _expectNoBodyActions(hits);
  });

  testWidgets('菜单淡出时仍阻断点击，消失后恢复正文点击', (tester) async {
    final (reader, hits) = await _pumpMenu(tester);
    reader.hideControls();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(const Offset(792, 300));
    _expectNoBodyEvents(hits);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(792, 300));
    expect(hits.bodyPointers, greaterThan(0));
    expect(hits.bodyTaps, 1);
  });

  testWidgets('菜单刚打开且淡入尚未开始时，正文区域也只关闭菜单', (tester) async {
    final (reader, hits) = await _pumpMenu(tester);
    reader.hideControls();
    await tester.pumpAndSettle();
    reader.toggleControls();
    await tester.pump();
    await tester.tapAt(const Offset(792, 300));
    await tester.pump();
    expect(reader.value.showControls, isFalse);
    _expectNoBodyActions(hits);
  });

  for (final x in [8.0, 400.0, 792.0]) {
    testWidgets('真实阅读器菜单外 x=$x 点击不翻页，关闭后恢复右侧翻页', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [
          readerNotifierProvider.overrideWith(_ScreenReader.new),
          bookApiProvider.overrideWithValue(MockBookApi()),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ReaderScreen()),
        ),
      );
      await tester.pumpAndSettle();
      final pages = tester.state<ReaderPageViewState>(
        find.byType(ReaderPageView),
      );
      expect(pages.pageCount, greaterThan(2));
      final before = container.read(readerNotifierProvider).currentChapterPos;
      await tester.tapAt(Offset(x, 300));
      await tester.pump();
      expect(container.read(readerNotifierProvider).showControls, isFalse);
      expect(container.read(readerNotifierProvider).currentChapterPos, before);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(792, 300));
      await tester.pumpAndSettle();
      expect(
        container.read(readerNotifierProvider).currentChapterPos,
        before + 1,
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final dx in [-300.0, 300.0]) {
    testWidgets('真实阅读器菜单外横滑 $dx 收起菜单并完成翻页', (tester) async {
      final container = await _pumpReader(tester);
      final before = container.read(readerNotifierProvider).currentChapterPos;
      await tester.dragFrom(const Offset(400, 300), Offset(dx, 0));
      await tester.pumpAndSettle();
      expect(container.read(readerNotifierProvider).showControls, isFalse);
      expect(
        container.read(readerNotifierProvider).currentChapterPos,
        before + (dx < 0 ? 1 : -1),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('菜单完全淡出后，同一个按住的指针仍可继续翻页', (tester) async {
    final container = await _pumpReader(tester);
    final before = container.read(readerNotifierProvider).currentChapterPos;
    final gesture = await tester.startGesture(const Offset(400, 300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(container.read(readerNotifierProvider).showControls, isFalse);
    await gesture.moveBy(const Offset(-300, 0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(
      container.read(readerNotifierProvider).currentChapterPos,
      before + 1,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('菜单淡出后才松手的点击不会误触正文翻页', (tester) async {
    final container = await _pumpReader(tester);
    final before = container.read(readerNotifierProvider).currentChapterPos;
    final gesture = await tester.startGesture(const Offset(792, 300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(container.read(readerNotifierProvider).showControls, isFalse);
    expect(container.read(readerNotifierProvider).currentChapterPos, before);
    expect(tester.takeException(), isNull);
  });

  testWidgets('滚动阅读上下滑均关闭菜单并继续滚动正文', (tester) async {
    final container = await _pumpReader(tester, mode: PageTurnMode.scroll);
    final scrollable = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byType(ReaderPageView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    final before = scrollable.position.pixels;
    await tester.dragFrom(const Offset(400, 360), const Offset(0, -180));
    await tester.pumpAndSettle();
    final afterUp = scrollable.position.pixels;
    expect(container.read(readerNotifierProvider).showControls, isFalse);
    expect(afterUp, greaterThan(before));
    container.read(readerNotifierProvider.notifier).toggleControls();
    await tester.pumpAndSettle();
    await tester.dragFrom(const Offset(400, 240), const Offset(0, 180));
    await tester.pumpAndSettle();
    expect(container.read(readerNotifierProvider).showControls, isFalse);
    expect(scrollable.position.pixels, lessThan(afterUp));
    expect(tester.takeException(), isNull);
  });

  const onlineBook = Book(
    bookUrl: 'https://source.test/book/1',
    name: '菜单点击测试',
    origin: 'https://source.test',
  );
  ReaderState linkState(BookChapter chapter, {Book book = onlineBook}) =>
      ReaderState(currentBook: book, chapters: [chapter], showControls: true);

  for (final (chapter, expectedUrl) in [
    (
      const BookChapter(title: '章节网页', url: 'https://source.test/1.html?q=1'),
      'https://source.test/1.html?q=1',
    ),
    (
      const BookChapter(
        title: '章节网页',
        url: '../1.html',
        baseUrl: 'https://source.test/book/toc.html',
      ),
      'https://source.test/1.html',
    ),
    (
      const BookChapter(
        title: '章节网页',
        url: '//source.test/1.html',
        baseUrl: 'http://source.test/toc.html',
      ),
      'http://source.test/1.html',
    ),
  ]) {
    testWidgets('点击章节名打开当前章节网页：$expectedUrl', (tester) async {
      RouteSettings? opened;
      final (reader, hits) = await _pumpMenu(
        tester,
        initialState: linkState(chapter),
        onGenerateRoute: (settings) {
          opened = settings;
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const Scaffold(body: Text('章节浏览页')),
          );
        },
      );
      await tester.tap(find.text('章节网页'));
      await tester.pumpAndSettle();
      expect(opened?.name, AppRoutes.browser);
      expect(opened?.arguments, {'url': expectedUrl, 'title': '章节链接'});
      expect(find.text('章节浏览页'), findsOneWidget);
      expect(reader.value.showControls, isTrue);
      _expectNoBodyEvents(hits);
      Navigator.of(tester.element(find.text('章节浏览页'))).pop();
      await tester.pumpAndSettle();
      expect(find.text('章节网页'), findsOneWidget);
      expect(reader.value.currentChapterIndex, 0);
    });
  }

  testWidgets('无网页地址、本地书及卷标题的章节名保持普通文字', (tester) async {
    final cases = [
      linkState(const BookChapter(title: '章节网页')),
      linkState(const BookChapter(title: '章节网页', url: 'chapter.html')),
      linkState(const BookChapter(title: '章节网页', url: 'https:/missing-host')),
      linkState(const BookChapter(title: '章节网页', url: 'http://[')),
      linkState(const BookChapter(title: '章节网页', url: 'file:///book.txt')),
      linkState(const BookChapter(title: '章节网页', url: 'javascript:alert(1)')),
      linkState(
        const BookChapter(
          title: '章节网页',
          url: 'https://source.test/1.html',
          isVolume: true,
        ),
      ),
      linkState(
        const BookChapter(title: '章节网页', url: 'https://source.test/1.html'),
        book: const Book(bookUrl: 'local.txt', origin: BookType.localTag),
      ),
    ];
    for (final state in cases) {
      var opens = 0;
      final (reader, hits) = await _pumpMenu(
        tester,
        initialState: state,
        onGenerateRoute: (_) {
          opens++;
          return MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('不应打开')),
          );
        },
      );
      expect(find.byTooltip('打开章节网页'), findsNothing);
      await tester.tap(find.text('章节网页'));
      await tester.pumpAndSettle();
      expect(
        opens,
        0,
        reason: '${state.currentBook?.origin} ${state.currentChapter?.url}',
      );
      expect(reader.value.showControls, isTrue);
      _expectNoBodyEvents(hits);
    }
  });

  for (final failed in [false, true]) {
    testWidgets('章节链接沿用系统浏览器偏好，打开${failed ? '失败有提示' : '成功'}', (tester) async {
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call);
        if (failed) throw PlatformException(code: '打开失败');
        return true;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      var routes = 0;
      final (reader, hits) = await _pumpMenu(
        tester,
        initialState: linkState(
          const BookChapter(title: '章节网页', url: 'https://source.test/1.html'),
        ),
        onGenerateRoute: (_) {
          routes++;
          return MaterialPageRoute<void>(builder: (_) => const SizedBox());
        },
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('readUrlInBrowser', true);
      await tester.tap(find.text('章节网页'));
      await tester.pumpAndSettle();
      expect(calls, hasLength(1));
      expect(calls.single.method, 'launch');
      expect(calls.single.arguments['url'], 'https://source.test/1.html');
      expect(calls.single.arguments['useWebView'], isFalse);
      expect(routes, 0);
      expect(reader.value.showControls, isTrue);
      _expectNoBodyEvents(hits);
      if (failed) {
        expect(find.text('无法打开链接：https://source.test/1.html'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
