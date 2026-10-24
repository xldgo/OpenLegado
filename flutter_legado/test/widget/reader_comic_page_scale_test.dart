import 'package:flutter_legado/src/features/reader_comic/presentation/overlays/manga_config_sheet.dart';
import 'package:flutter_legado/src/features/reader_comic/presentation/views/comic_image_item.dart';
import 'package:flutter_legado/src/data/services/comic_image_decode_cache.dart';
import 'package:flutter_legado/src/features/reader_comic/presentation/views/comic_wide_page.dart';
import 'package:flutter_legado/src/features/reader_comic/application/comic_page_layout.dart';

import '../fixtures/app_test_api.dart';
import '../fixtures/config_repository.dart';
import '../mocks/book_image_fixture.dart';

import 'package:flutter_legado/src/domain/contracts/book_image_repository.dart';

import '../mocks/reading_fixture.dart';
import '../mocks/book_source_fixture.dart';
import '../mocks/bookshelf_fixture.dart';

// [P4-3 E2] 分页适配类型（设置项 + 持久化，整页行为）
//
// 取证（参考版，legado-with-MD3）：
// - MangaSettingsPanel.kt L372-386：非条漫模式显示「页面适配」6 选项下拉
//   → UpdateSetting(PAGE_SCALE_TYPE)；L364-371 条漫模式改显侧边距滑杆
//   （侧边距已由 [P4-3 M3 修4] 落地为「侧边留白」滑杆 0..45%，
//   故条漫模式下仍不渲染「页面适配」项）；
// - MangaReaderContract.kt L121：默认 0；MangaReaderViewModel.kt L816
//   PAGE_SCALE_TYPE → updateMangaPreference（持久化）。
//
// 本测试验证：
// 1. 单页模式（模式 1）：设置面板出现「页面适配」下拉（默认「全屏适配」），
//    切换「拉伸」→ 持久化 mangaPageScaleType=1；
// 2. 条漫模式（默认 4）：设置面板不渲染「页面适配」项；
// 3. 已配置值（mangaPageScaleType=3）：下拉回显「适配高度」。
import 'dart:convert';
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/features/reader_comic/presentation/reader_comic_screen.dart';

/// 1x1 透明 PNG（合法 68 字节编码）
const _kPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGNgAAIAAAUAAXpeqz8'
    'AAAAASUVORK5CYII=';

/// 页面适配测试 Mock：可注入配置（翻页模式/适配类型），记录配置写入
class _ScaleMockApi extends MockBookApi {
  late final _fixtureImages = TestBookImageRepository(
    delegate: super.bookImageRepository,
    fetch: _fixtureFetchImage,
    read: _fixtureGetImageCache,
  );
  @override
  BookImageRepository get bookImageRepository => _fixtureImages;

  late final _fixtureReading = TestReadingRepository(
    delegate: super.readingRepository,
    getChapters: _readingGetChapters,
    fetchChapterContent: _readingFetchChapterContent,
    updateReadingProgress: _readingUpdateReadingProgress,
  );
  @override
  TestReadingRepository get readingRepository => _fixtureReading;

  late final _fixtureSources = TestBookSourceRepository(
    delegate: super.bookSourceRepository,
    getBookSources: _fixtureGetBookSources,
  );
  @override
  TestBookSourceRepository get bookSourceRepository => _fixtureSources;

  late final _fixtureShelf = TestBookshelfRepository(
    delegate: super.bookshelfRepository,
    getBook: _fixtureGetBook,
  );
  @override
  TestBookshelfRepository get bookshelfRepository => _fixtureShelf;

  _ScaleMockApi({
    required this.configWrites,
    Map<String, String>? configs,
    this.imageCacheRead,
    this.imageCount = 3,
  }) : _configs = configs ?? {};

  /// 每章图片数（与 E1/E3 mock 一致取 3，保证单页式有页可翻）
  final int imageCount;

  final List<List<String>> configWrites;
  final Future<List<int>?> Function(String)? imageCacheRead;
  final progress = <(int, int)>[];
  final imageRequests = <String>[];
  final Map<String, String> _configs;

  Future<List<BookSource>> _fixtureGetBookSources() async => [
    BookSource(
      bookSourceUrl: 'https://manga.example.com',
      bookSourceName: '测试漫画源',
      bookSourceGroup: '漫画',
      bookSourceType: 2,
      enabled: true,
      ruleContent: ContentRule(content: '.x', imageDecode: 'decode(result);'),
      customOrder: 0,
      lastUpdateTime: 0,
      respondTime: 0,
      weight: 0,
    ),
  ];

  Future<Book?> _fixtureGetBook(String bookUrl) async => Book(
    bookUrl: bookUrl,
    tocUrl: 'https://manga.example.com/comic/1/',
    name: '测试漫画',
    author: '作者',
    origin: 'https://manga.example.com',
    originName: '测试漫画源',
    canUpdate: true,
    totalChapterNum: 1,
    durChapterPos: 0,
  );

  Future<List<BookChapter>> _readingGetChapters(String bookUrl) async => [
    BookChapter(
      index: 0,
      url: 'https://manga.example.com/comic/1/ch1.html',
      title: '第1章',
    ),
  ];

  Future<String> _readingFetchChapterContent(
    String bookUrl,
    String chapterUrl,
    String sourceUrl,
  ) async {
    return List.generate(
      imageCount,
      (i) => '<p><img src="https://cdn.example.com/img/$i.jpg"></p>',
    ).join();
  }

  Future<String> _fixtureFetchImage(String url, String sourceJson) async {
    imageRequests.add(url);
    return jsonEncode({'base64': _kPngBase64, 'len': 68});
  }

  @override
  TestConfigRepository get configRepository => _fixtureConfig;
  late final _fixtureConfig = TestConfigRepository(
    read: _fixturegetConfig,
    write: _fixturesetConfig,
  );

  Future<String?> _fixturegetConfig(String key) async => _configs[key];

  Future<void> _fixturesetConfig(String key, String value) async {
    configWrites.add([key, value]);
  }

  Future<void> _readingUpdateReadingProgress({
    required String bookUrl,
    required int chapterIndex,
    required int chapterPos,
  }) async {
    progress.add((chapterIndex, chapterPos));
  }

  Future<List<int>?> _fixtureGetImageCache(String bookUrl, String url) async =>
      imageCacheRead == null ? null : await imageCacheRead!(url);
}

/// 打开漫画设置面板（控制栏 → 底栏「翻页设置」键 [P4-3 M1]）
Future<void> _openSheet(WidgetTester tester) async {
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  await tester.tapAt(Offset(size.width / 2, size.height / 2));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('翻页设置'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ComicImageDecodeCache.clearForTest();
  });
  tearDown(ComicImageDecodeCache.clearForTest);
  testWidgets('双页跳页跨多组定位第二图，后续翻页不沿用旧跳页目标', (tester) async {
    final api = _ScaleMockApi(
      configWrites: [],
      imageCount: 7,
      configs: {
        'mangaScrollMode': '1',
        'mangaDoublePageMode': '2',
        'mangaPreDownloadNum': '0',
      },
    );
    final container = ProviderContainer(
      overrides: mergeTestOverrides([...api.overrides]),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ReaderComicScreen(bookUrl: 'mock://double-seek'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(400, 300));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Slider), const Offset(1000, 0));
    await tester.pumpAndSettle();
    expect(find.textContaining('页数7/7'), findsOneWidget);
    expect(api.progress.last, (0, 6));
    await tester.drag(find.byType(PageView), const Offset(650, 0));
    await tester.pumpAndSettle();
    expect(find.textContaining('页数4/7'), findsOneWidget);
    expect(api.progress.last, (0, 3));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
  for (final mode in [1, 2]) {
    testWidgets('双页模式$mode：横屏配对、左右交换和返回竖屏保留原图', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(600, 900);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final api = _ScaleMockApi(
        configWrites: [],
        configs: {
          'mangaScrollMode': '$mode',
          'mangaDoublePageMode': '1',
          'mangaPreDownloadNum': '0',
        },
      );
      final container = ProviderContainer(
        overrides: mergeTestOverrides([...api.overrides]),
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ReaderComicScreen(bookUrl: 'mock://double'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      PageView pager() => tester.widget<PageView>(find.byType(PageView));
      expect(pager().childrenDelegate.estimatedChildCount, 4);
      tester.view.physicalSize = const Size(1000, 600);
      await tester.pumpAndSettle();
      expect(
        pager().childrenDelegate.estimatedChildCount,
        3,
        reason: '横屏首图独立，后两图配对，章尾导航保持独立',
      );
      await tester.drag(
        find.byType(PageView),
        Offset(mode == 1 ? -850 : 850, 0),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('页数2/3'), findsOneWidget);
      expect(api.progress, contains((0, 1)));
      Finder image(int index) => find.byWidgetPredicate(
        (widget) =>
            widget is ComicImageItem && widget.url.endsWith('/$index.jpg'),
      );
      final left = tester.getRect(image(1));
      final right = tester.getRect(image(2));
      expect(
        mode == 1 ? left.left < right.left : left.left > right.left,
        isTrue,
      );
      expect(left.width, right.width);
      await _openSheet(tester);
      final invert = find.widgetWithText(SwitchListTile, '交换左右页');
      await tester.ensureVisible(invert);
      await tester.pumpAndSettle();
      await tester.tap(invert);
      await tester.pumpAndSettle();
      expect(
        api.configWrites,
        contains(equals(['mangaDoublePageInvert', 'true'])),
      );
      Navigator.of(tester.element(find.byType(MangaConfigSheet))).pop();
      await tester.pumpAndSettle();
      expect(
        mode == 1
            ? tester.getRect(image(1)).left > tester.getRect(image(2)).left
            : tester.getRect(image(1)).left < tester.getRect(image(2)).left,
        isTrue,
      );
      expect(find.textContaining('页数2/3'), findsOneWidget);
      if (mode == 1) {
        final pageBeforeSeek = pager().controller!.page;
        await tester.drag(find.byType(Slider), const Offset(1000, 0));
        await tester.pumpAndSettle();
        expect(
          pager().controller!.page,
          pageBeforeSeek,
          reason: '配对内跳到第二张原图无需翻到另一显示页',
        );
        expect(find.textContaining('页数3/3'), findsOneWidget);
        expect(api.progress.last, (0, 2));
      }
      tester.view.physicalSize = const Size(600, 900);
      await tester.pumpAndSettle();
      expect(pager().childrenDelegate.estimatedChildCount, 4);
      expect(
        find.textContaining(mode == 1 ? '页数3/3' : '页数2/3'),
        findsOneWidget,
        reason: '配对解散后仍保留该原图，不能按旧显示页索引恢复',
      );
      // 竖屏下可改为始终配对，关闭后回到原图，而不是沿用配对页码。
      if (mode == 1) {
        await tester.tapAt(const Offset(300, 450));
        await tester.pumpAndSettle();
        await _openSheet(tester);
        final dropdown = find.text('仅横屏');
        await tester.ensureVisible(dropdown);
        await tester.pumpAndSettle();
        await tester.tap(dropdown);
        await tester.pumpAndSettle();
        await tester.tap(find.text('始终开启').last);
        await tester.pumpAndSettle();
        expect(pager().childrenDelegate.estimatedChildCount, 3);
        expect(
          api.configWrites,
          contains(equals(['mangaDoublePageMode', '2'])),
        );
        await tester.tap(find.text('始终开启'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('关闭').last);
        await tester.pumpAndSettle();
        expect(pager().childrenDelegate.estimatedChildCount, 4);
        expect(
          find.textContaining(mode == 1 ? '页数3/3' : '页数2/3'),
          findsOneWidget,
        );
        Navigator.of(tester.element(find.byType(MangaConfigSheet))).pop();
        await tester.pumpAndSettle();
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }
  for (final mode in [1, 2]) {
    testWidgets('宽页拆分模式$mode：半页翻动/窗口重排保持原图进度，关闭拆分后仍在原图', (tester) async {
      final wide = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAIAAAABCAYAAAD0In+KAAAAC0lEQVR4nGP4DwUAI+UH+Yo0eLMAAAAASUVORK5CYII=',
      );
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.runAsync(
        () => precacheImage(
          MemoryImage(wide),
          tester.element(find.byType(SizedBox)),
        ),
      );
      const imageUrl = 'https://cdn.example.com/img/0.jpg';
      ComicImageDecodeCache.put('https://manga.example.com', imageUrl, wide);
      final delayedImage = Completer<List<int>?>();
      final api = _ScaleMockApi(
        configWrites: [],
        imageCacheRead: mode == 1
            ? (url) async =>
                  url.endsWith('/1.jpg') ? await delayedImage.future : null
            : null,
        configs: {
          'mangaScrollMode': '$mode',
          'mangaWidePageMode': '3',
          'mangaDoublePageMode': mode == 1 ? '2' : '0',
          'mangaPreDownloadNum': '0',
        },
      );
      final container = ProviderContainer(
        overrides: mergeTestOverrides([...api.overrides]),
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ReaderComicScreen(bookUrl: 'mock://wide'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      PageView pager() => tester.widget<PageView>(find.byType(PageView));
      expect(
        pager().childrenDelegate.estimatedChildCount,
        mode == 1 ? 4 : 5,
        reason: '宽图拆分优先，剩余竖图按双页设置配对，最后为章尾导航',
      );
      expect(find.textContaining('页数1/3'), findsOneWidget);
      final firstSlice = mode == 1 ? ComicPageSlice.left : ComicPageSlice.right;
      final secondSlice = mode == 1
          ? ComicPageSlice.right
          : ComicPageSlice.left;
      expect(
        tester
            .widgetList<ComicWidePage>(find.byType(ComicWidePage))
            .any((page) => page.slice == firstSlice),
        isTrue,
      );
      final direction = mode == 1 ? -1.0 : 1.0;
      await tester.drag(find.byType(PageView), Offset(direction * 650, 0));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('页数1/3'),
        findsOneWidget,
        reason: '第二半仍属于第一张原图',
      );
      expect(api.progress, isEmpty);
      final display = pager().controller!.page!.round();
      if (mode == 1) {
        // 相邻图在拖动途中才解码为宽图，先保持旧显示列表，结束后再重排。
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(PageView)),
        );
        await gesture.moveBy(const Offset(-30, 0));
        await tester.pump(const Duration(milliseconds: 16));
        await gesture.moveBy(const Offset(-120, 0));
        await tester.pump(const Duration(milliseconds: 100));
        delayedImage.complete(wide);
        final nextImage = find.descendant(
          of: find.byWidgetPredicate(
            (widget) =>
                widget is ComicImageItem && widget.url.endsWith('/1.jpg'),
          ),
          matching: find.byType(RawImage),
        );
        bool nextDecoded() => tester
            .widgetList<RawImage>(nextImage)
            .any(
              (image) => image.image?.width == 2 && image.image?.height == 1,
            );
        // 实际codec运行在引擎线程，不能只推进测试假时间就假定尺寸已返回。
        for (var attempt = 0; attempt < 50 && !nextDecoded(); attempt++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
        }
        expect(nextDecoded(), isTrue);
        await tester.pumpAndSettle();
        expect(pager().childrenDelegate.estimatedChildCount, 4);
        await tester.pump(const Duration(milliseconds: 200));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(pager().childrenDelegate.estimatedChildCount, 6);
        expect(pager().controller!.page!.round(), display);
      }

      final activeWidePage = find.descendant(
        of: find.byType(PageView),
        matching: find.byWidgetPredicate(
          (widget) => widget is ComicWidePage && widget.slice == secondSlice,
        ),
      );
      expect(activeWidePage, findsOneWidget);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(600, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpAndSettle();
      expect(pager().controller!.page!.round(), display);
      expect(find.textContaining('页数1/3'), findsOneWidget);
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      await tester.pumpAndSettle();
      await tester.drag(find.byType(PageView), Offset(direction * 650, 0));
      await tester.pumpAndSettle();
      expect(find.textContaining('页数2/3'), findsOneWidget);
      expect(api.progress, contains((0, 1)));
      await tester.drag(find.byType(PageView), Offset(-direction * 650, 0));
      await tester.pumpAndSettle();
      expect(find.textContaining('页数1/3'), findsOneWidget);
      await _openSheet(tester);
      await tester.ensureVisible(find.text('拆分'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('拆分'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('普通').last);
      await tester.pumpAndSettle();
      expect(api.configWrites, contains(equals(['mangaWidePageMode', '0'])));
      Navigator.of(tester.element(find.text('宽页处理'))).pop();
      await tester.pumpAndSettle();
      expect(pager().childrenDelegate.estimatedChildCount, 4);
      expect(find.textContaining('页数1/3'), findsOneWidget);
      expect(
        api.imageRequests.where((url) => url == imageUrl),
        isEmpty,
        reason: '两半显示仍复用同一份原图缓存',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }

  group('[P4-3 E2] 分页适配类型设置项', () {
    testWidgets('单页模式：下拉切换「拉伸」→ 持久化 mangaPageScaleType=1', (tester) async {
      final configWrites = <List<String>>[];
      final api = _ScaleMockApi(
        configWrites: configWrites,
        configs: {'mangaScrollMode': '1'},
      );
      final container = ProviderContainer(
        overrides: mergeTestOverrides([...api.overrides]),
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ReaderComicScreen(bookUrl: 'mock://s1'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('页数1/3'), findsOneWidget);

      await _openSheet(tester);

      // 「页面适配」下拉（单页模式才渲染，对齐参考版 L372-386）
      expect(find.text('页面适配'), findsOneWidget);
      // 默认值 0 = 全屏适配（Contract L121）
      expect(find.text('全屏适配'), findsOneWidget);

      // 打开下拉选「拉伸」：菜单打开后舞台上恰有 1 个「拉伸」菜单项
      // （隐藏层另有 1 个离舞台副本，故按默认 skipOffstage 定位）
      await tester.tap(find.text('全屏适配'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('拉伸'));
      await tester.pumpAndSettle();

      expect(
        configWrites,
        contains(equals(['mangaPageScaleType', '1'])),
        reason: '切换「拉伸」应持久化到 mangaPageScaleType',
      );
    });

    testWidgets('条漫模式（默认）：不渲染「页面适配」项', (tester) async {
      final api = _ScaleMockApi(configWrites: <List<String>>[]);
      final container = ProviderContainer(
        overrides: mergeTestOverrides([...api.overrides]),
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ReaderComicScreen(bookUrl: 'mock://s2'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _openSheet(tester);

      // 条漫模式 [P4-3 M3 修4]：阅读模式改 5 按钮组（M2「翻页模式」下拉
      // 已移除）且屏侧接线后显「侧边留白」滑杆 → 仍无「页面适配」项
      expect(find.text('页面适配'), findsNothing);
      expect(find.text('阅读模式'), findsOneWidget);
      expect(find.text('侧边留白'), findsOneWidget);
    });

    testWidgets('已配置 mangaPageScaleType=3：下拉回显「适配高度」', (tester) async {
      final api = _ScaleMockApi(
        configWrites: <List<String>>[],
        configs: {'mangaScrollMode': '1', 'mangaPageScaleType': '3'},
      );
      final container = ProviderContainer(
        overrides: mergeTestOverrides([...api.overrides]),
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ReaderComicScreen(bookUrl: 'mock://s3'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _openSheet(tester);

      expect(find.text('适配高度'), findsOneWidget);
    });
  });
}
