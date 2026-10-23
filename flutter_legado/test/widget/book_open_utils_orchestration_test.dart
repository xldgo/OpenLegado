import '../fixtures/routing_test_app.dart';

import 'dart:ui' as ui;

import '../fixtures/app_test_api.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/features/reader/application/reader_notifier.dart';
import 'package:flutter_legado/src/app/routing/route_names.dart';
import 'package:flutter_legado/src/services/platform_bridge_service.dart';
import 'package:flutter_legado/src/utils/book_open_utils.dart';
import 'package:flutter_legado/src/widgets/book_cover.dart';

import '../mocks/mocks.dart';

/// [P2-E | 2026-09-30] BookOpenUtils.openBook 统一开书编排测试
/// （4 屏收敛后的公共入口）：
/// - 零进度书籍直接进入对应阅读器或播放器；
/// - 在线书籍按 origin 匹配书源（尾斜杠归一）解析类型位 → 视频路由；
/// - 欢迎页口径：全局 navigatorKey 导航，复用相同直开规则；
/// - 文本阅读器：先经 ReaderNotifier.openBook 装载再导航（无 arguments）。
/// — 全栈工程师 + UI
void main() {
  late ui.Image cover;
  setUpAll(() async {
    registerFallbacks();
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      const Rect.fromLTWH(0, 0, 40, 56),
      Paint()..color = Colors.orange,
    );
    final picture = recorder.endRecording();
    cover = await picture.toImage(40, 56);
    picture.dispose();
  });
  tearDownAll(() => cover.dispose());

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// 记录 push 的路由（名称 + 参数）
  final observer = _RouteLogObserver();

  tearDown(() {
    observer.routes.clear();
  });

  /// 测试宿主：按钮点击触发 BookOpenUtils.openBook；
  /// 任意命名路由统一渲染 stub 页（避免 MaterialApp 未注册路由报错）
  Widget harness({
    required Book book,
    required MockRustApi api,
    _RecordingReaderNotifier? readerNotifier,
    bool useGlobalNavigator = false,
    bool withCover = false,
  }) {
    return ProviderScope(
      overrides: mergeTestOverrides([
        ...api.overrides,
        if (readerNotifier != null)
          readerNotifierProvider.overrideWith(() => readerNotifier),
      ]),
      child: RoutingTestApp(
        navigatorKey: useGlobalNavigator
            ? PlatformBridgeService.navigatorKey
            : null,
        navigatorObservers: [observer],
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => Scaffold(body: Text('stub:${settings.name}')),
        ),
        home: Consumer(
          builder: (context, ref, _) => Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (withCover)
                    BookCoverHero(
                      tag: 'entry:${book.bookUrl}',
                      child: RawImage(image: cover, width: 80, height: 112),
                    ),
                  ElevatedButton(
                    onPressed: () => BookOpenUtils.openBook(
                      context,
                      ref,
                      book,
                      useGlobalNavigator: useGlobalNavigator,
                      coverContext: withCover ? context : null,
                    ),
                    child: const Text('open'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('零进度书籍直接打开文本阅读器，返回不经过详情', (tester) async {
    const book = Book(bookUrl: 'https://ex.com/unread', name: '未读书');
    final api = MockRustApi();
    final reader = _RecordingReaderNotifier();

    await tester.pumpWidget(
      harness(book: book, api: api, readerNotifier: reader),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(observer.lastName, AppRoutes.reader);
    expect((observer.lastArguments as Book).bookUrl, book.bookUrl);
    expect(reader.openedBook, book);
    expect(
      observer.routes.map((route) => route.settings.name),
      isNot(contains(AppRoutes.bookInfo)),
    );
    Navigator.of(tester.element(find.text('stub:${AppRoutes.reader}'))).pop();
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('普通开书入口传递点击区域内的封面，保留书籍身份及正文装载', (tester) async {
    const book = Book(bookUrl: 'book://local-cover', name: '普通入口封面');
    final reader = _RecordingReaderNotifier();
    await tester.pumpWidget(
      harness(
        book: book,
        api: MockRustApi(),
        readerNotifier: reader,
        withCover: true,
      ),
    );
    await tester.pumpAndSettle();
    final bounds = tester.getRect(find.byType(BookCoverHero));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(observer.lastName, AppRoutes.reader);
    final origin = observer.lastArguments! as BookCoverOrigin;
    expect(origin.bookUrl, book.bookUrl);
    expect(origin.bounds()?.size, bounds.size);
    expect(
      origin.bounds(),
      tester.getRect(find.byType(BookCoverHero, skipOffstage: false)),
    );
    expect(origin.image()!.isCloneOf(cover), isTrue);
    expect(reader.openedBook, book);
  });

  testWidgets('零进度在线书源匹配（尾斜杠归一 type=4）→ 视频路由且带类型位更新', (tester) async {
    final api = MockRustApi();
    when(() => api.bookSourceRepository.getBookSources()).thenAnswer(
      (_) async => const [
        BookSource(
          bookSourceUrl: 'https://video.example.com',
          bookSourceName: '影视源',
          bookSourceType: 4,
        ),
      ],
    );
    when(
      () => api.bookSourceQueryService.resolveReadingType(BookType.text, any()),
    ).thenAnswer((_) async => BookType.video);
    // origin 带尾斜杠、书源 URL 不带：归一后应匹配（旧 home_tab 精确比较会漏配）
    const book = Book(
      bookUrl: 'https://video.example.com/play/1',
      name: '视频书',
      origin: 'https://video.example.com/',
      originName: '影视源',
      bookType: BookType.text,
    );

    await tester.pumpWidget(harness(book: book, api: api));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(observer.lastName, AppRoutes.video);
    final args = observer.lastArguments;
    expect(args, isA<Book>());
    final argBook = args! as Book;
    expect(argBook.bookUrl, book.bookUrl);
    expect(argBook.bookType & BookType.video, BookType.video);
    expect(argBook.bookType & BookType.text, 0);
    verify(() => api.bookSourceRepository.getBookSources()).called(1);
    final resolvedSource =
        verify(
              () => api.bookSourceQueryService.resolveReadingType(
                BookType.text,
                captureAny(),
              ),
            ).captured.single
            as BookSource;
    expect(resolvedSource.bookSourceUrl, 'https://video.example.com');
  });

  testWidgets('欢迎页口径：全局 navigatorKey 直开零进度文本书', (tester) async {
    const book = Book(
      bookUrl: 'loc_book_1',
      name: '本地未读书',
      origin: BookType.localTag,
      durChapterIndex: 0,
      durChapterPos: 0,
      bookType: BookType.text,
    );
    final api = MockRustApi();
    final reader = _RecordingReaderNotifier();

    await tester.pumpWidget(
      harness(
        book: book,
        api: api,
        readerNotifier: reader,
        useGlobalNavigator: true,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // 全局导航与页面导航均直接打开对应阅读器。
    expect(observer.lastName, AppRoutes.reader);
    expect((observer.lastArguments as Book).bookUrl, book.bookUrl);
    expect(reader.openedBook?.bookUrl, book.bookUrl);
  });

  testWidgets('文本阅读器：先装载 ReaderNotifier 再推 /reader（携带身份快照）', (tester) async {
    const book = Book(
      bookUrl: 'loc_book_2',
      name: '本地已读书',
      origin: BookType.localTag,
      durChapterIndex: 2,
      durChapterPos: 10,
      bookType: BookType.text,
    );
    final api = MockRustApi();
    final reader = _RecordingReaderNotifier();

    await tester.pumpWidget(
      harness(book: book, api: api, readerNotifier: reader),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(observer.lastName, AppRoutes.reader);
    expect((observer.lastArguments as Book).bookUrl, book.bookUrl);
    expect(reader.openedBook, book);
  });

  testWidgets('零进度音频书直接进入播放器并保留书籍参数', (tester) async {
    const book = Book(
      bookUrl: 'audio://unread',
      name: '未读音频书',
      bookType: BookType.audio,
    );
    final reader = _RecordingReaderNotifier();
    await tester.pumpWidget(
      harness(book: book, api: MockRustApi(), readerNotifier: reader),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(observer.lastName, AppRoutes.audio);
    expect(observer.lastArguments, book);
    expect(reader.openedBook, isNull);
  });

  // [cbz 批 C | 2026-10-03] cbz 漫画包开书路由钉住：Rust importLocalBook
  // 对 .cbz 返回 bookType=LOCAL|image(0x1040)，BookOpenUtils 位域路由须
  // 进 /reader-comic（零代码改动，补测试防回归）。
  test('类型位常量：LOCAL|image=0x1040（与 Rust book_type LOCAL|IMAGE_BIT 对齐）', () {
    expect(BookType.local, 0x1000);
    expect(BookType.image, 64);
    expect(BookType.local | BookType.image, 0x1040);
    expect(
      BookOpenUtils.routeForTypeBits(BookType.image),
      AppRoutes.readerComic,
    );
  });

  testWidgets('本地 cbz（LOCAL|image=0x1040）→ 漫画阅读器 /reader-comic（参数 bookUrl）', (
    tester,
  ) async {
    const book = Book(
      bookUrl: 'file:///storage/books/本地漫画.cbz',
      name: '本地漫画',
      origin: BookType.localTag,
      bookType: BookType.local | BookType.image,
      durChapterPos: 0,
    );
    final api = MockRustApi();
    final reader = _RecordingReaderNotifier();

    await tester.pumpWidget(
      harness(book: book, api: api, readerNotifier: reader),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // 本地书不做书源匹配；媒体位 image 直接路由漫画阅读器并传 bookUrl
    expect(observer.lastName, AppRoutes.readerComic);
    expect(observer.lastArguments, book.bookUrl);
    // 不走文本阅读器装载（needsReaderNotifier=false）
    expect(reader.openedBook, isNull);
    verifyNever(() => api.bookSourceRepository.getBookSources());
  });
}

/// 路由日志观察者：断言最终 push 的路由名与参数
class _RouteLogObserver extends NavigatorObserver {
  final List<Route<dynamic>> routes = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    routes.add(route);
    super.didPush(route, previousRoute);
  }

  String? get lastName => routes.last.settings.name;

  Object? get lastArguments => routes.last.settings.arguments;
}

/// 记录 openBook 调用的 ReaderNotifier 假实现（隔离真实阅读器状态加载）
class _RecordingReaderNotifier extends ReaderNotifier {
  Book? openedBook;

  @override
  ReaderState build() => const ReaderState();

  @override
  Future<void> openBook(Book book) async {
    openedBook = book;
  }
}
