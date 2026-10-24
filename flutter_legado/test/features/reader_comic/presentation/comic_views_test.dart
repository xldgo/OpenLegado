import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_legado/src/data/services/comic_image_decode_cache.dart';
import 'package:flutter_legado/src/domain/contracts/book_image_repository.dart';
import 'package:flutter_legado/src/domain/contracts/local_book_service.dart';
import 'package:flutter_legado/src/domain/contracts/network_service.dart';
import 'package:flutter_legado/src/features/reader_comic/presentation/views/comic_image_item.dart';
import 'package:flutter_legado/src/features/reader_comic/presentation/views/comic_webtoon_view.dart';
import 'package:flutter_legado/src/models/models.dart';

class _Images extends Mock implements BookImageRepository {}

class _LocalBooks extends Mock implements LocalBookService {}

class _Network extends Mock implements NetworkService {}

void main() {
  late _Images images;
  late _LocalBooks localBooks;
  late _Network network;
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGP4DwQACfsD/fteaysAAAAASUVORK5CYII=',
  );
  setUp(() {
    ComicImageDecodeCache.clearForTest();
    images = _Images();
    localBooks = _LocalBooks();
    network = _Network();
  });
  tearDown(ComicImageDecodeCache.clearForTest);

  Widget image({
    String url = 'cbz://001.png',
    BookSource? source,
    bool failed = false,
    bool smartFit = false,
    VoidCallback? onError,
    VoidCallback? onRetry,
    VoidCallback? onLongPress,
  }) => MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: ComicImageItem(
          url: url,
          book: const Book(bookUrl: 'book', origin: 'source'),
          source: source,
          bookUrl: 'book',
          images: images,
          localBooks: localBooks,
          network: network,
          failed: failed,
          headers: const {},
          fit: BoxFit.contain,
          smartFit: smartFit,
          colorFilter: null,
          enableEInk: false,
          eInkThreshold: 150,
          disableCrossFade: true,
          onError: onError ?? () {},
          onRetry: onRetry ?? () {},
          onLongPress: onLongPress ?? () {},
        ),
      ),
    ),
  );

  testWidgets('CBZ图片可独立加载并直接复用共享缓存，不需要ProviderScope', (tester) async {
    ComicImageDecodeCache.put('book', 'cbz://001.png', png);
    await tester.pumpWidget(image());
    await tester.pumpAndSettle();
    expect(tester.widget<Image>(find.byType(Image)).image, isA<MemoryImage>());
    verifyZeroInteractions(localBooks);
    verifyZeroInteractions(images);
    verifyZeroInteractions(network);
  });

  testWidgets('CBZ图片失败通知后点击重试成功加载', (tester) async {
    var failures = 0;
    when(() => localBooks.cbzReadPage(path: 'book', entry: 'cbz://001.png'))
        .thenThrow(StateError('读取失败'));
    await tester.pumpWidget(image(onError: () => failures++));
    await tester.pumpAndSettle();
    expect(failures, 1);
    expect(find.text('重试'), findsOneWidget);
    when(() => localBooks.cbzReadPage(path: 'book', entry: 'cbz://001.png'))
        .thenAnswer((_) async => png);
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.text('重试'), findsNothing);
    expect(ComicImageDecodeCache.get('book', 'cbz://001.png'), png);
    expect(tester.takeException(), isNull);
  });

  testWidgets('书源图片磁盘命中直接显示，不进行网络解码', (tester) async {
    when(() => images.getImageCache('book', 'https://img/a'))
        .thenAnswer((_) async => png);
    await tester.pumpWidget(
      image(
        url: 'https://img/a',
        source: const BookSource(bookSourceUrl: 'source'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(RawImage), findsOneWidget);
    verifyNever(() => images.fetchImageWithDecode(any(), any()));
    verifyZeroInteractions(network);
  });

  testWidgets('智能适配读取已加载图片尺寸，宽图按宽适配且切换竖图后恢复完整显示', (tester) async {
    final wide = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAIAAAABCAYAAAD0In+KAAAAC0lEQVR4nGP4DwUAI+UH+Yo0eLMAAAAASUVORK5CYII=',
    );
    final portrait = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAACCAYAAACZgbYnAAAADklEQVR4nGP4DwQMIAIAJ+IH+dGbZDoAAAAASUVORK5CYII=',
    );
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final context = tester.element(find.byType(SizedBox));
    await tester.runAsync(() async {
      await precacheImage(MemoryImage(wide), context);
      await precacheImage(MemoryImage(portrait), context);
    });
    ComicImageDecodeCache.put('book', 'cbz://001.png', wide);
    await tester.pumpWidget(image(smartFit: true));
    await tester.pumpAndSettle();
    expect(tester.widget<RawImage>(find.byType(RawImage)).fit, BoxFit.fitWidth);
    // 同一渲染位置换为竖图，不能沿用上一张的宽页判定。
    ComicImageDecodeCache.put('book', 'cbz://002.png', portrait);
    await tester.pumpWidget(image(url: 'cbz://002.png', smartFit: true));
    await tester.pumpAndSettle();
    expect(tester.widget<RawImage>(find.byType(RawImage)).fit, BoxFit.contain);
    verifyZeroInteractions(localBooks);
    expect(tester.takeException(), isNull);
  });

  testWidgets('失败项的重试及长按各自分发，不自行启动数据请求', (tester) async {
    final actions = <String>[];
    await tester.pumpWidget(
      image(
        failed: true,
        onRetry: () => actions.add('retry'),
        onLongPress: () => actions.add('long'),
      ),
    );
    await tester.tap(find.text('重试'));
    await tester.longPress(find.text('图片加载失败'));
    expect(actions, ['retry', 'long']);
    verifyZeroInteractions(localBooks);
    verifyZeroInteractions(images);
  });

  testWidgets('条漫滚动到章节导航、间距留白及缩放保持独立输入', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    var navigations = 0;
    Widget view(bool disableScale) => MaterialApp(
      home: Scaffold(
        body: ComicWebtoonView(
          controller: controller,
          pageCount: 5,
          disableScale: disableScale,
          withGap: true,
          sidePadding: 10,
          pageBuilder: (_, index) =>
              SizedBox(height: 300, child: Text('图片$index')),
          navigationBuilder: (_) => TextButton(
            onPressed: () => navigations++,
            child: const Text('下一章'),
          ),
        ),
      ),
    );
    await tester.pumpWidget(view(true));
    await tester.pumpAndSettle();
    final width = tester.getSize(find.byType(Scaffold)).width;
    expect(tester.getTopLeft(find.text('图片0')).dx, closeTo(width * .1, .01));
    expect(tester.getTopLeft(find.text('图片0')).dy, 4);
    expect(find.byType(InteractiveViewer), findsNothing);
    await tester.scrollUntilVisible(find.text('下一章'), 250);
    await tester.tap(find.text('下一章'));
    expect(navigations, 1);
    await tester.pumpWidget(view(false));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
  });
  testWidgets('条漫按不等高图片报告位置，跳到未布局页不依赖整章高度', (tester) async {
    final scroll = ScrollController(keepScrollOffset: false);
    final anchors = ComicWebtoonAnchorController();
    addTearDown(scroll.dispose);
    final ranges = <(int, int)>[];
    final heights = [120.0, 1000.0, 250.0, 900.0, 180.0, 180.0, 1000.0, 700.0];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ComicWebtoonView(
            controller: scroll,
            anchors: anchors,
            initialPage: 2,
            pageCount: heights.length,
            disableScale: true,
            withGap: false,
            sidePadding: 0,
            onVisibleRangeChanged: (first, last) => ranges.add((first, last)),
            pageBuilder: (_, index) =>
                SizedBox(height: heights[index], child: Text('页$index')),
            navigationBuilder: (_) =>
                const SizedBox(height: 100, child: Text('导航')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(ranges.last.$1, 2);
    expect(tester.getTopLeft(find.text('页2')).dy, 0);
    scroll.jumpTo(300);
    await tester.pumpAndSettle();
    expect(ranges.last.$1, 3);
    anchors.jumpToPage(6);
    await tester.pumpAndSettle();
    expect(ranges.last.$1, 6);
    expect(tester.getTopLeft(find.text('页6')).dy, 0);
    scroll.jumpTo(-200);
    await tester.pumpAndSettle();
    expect(ranges.last.$1, 4);
    anchors.jumpToPage(0);
    await tester.pumpAndSettle();
    expect(ranges.last.$1, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('条漫恢复图片加载改高时保持图片起点，页尾导航不生成额外页码', (tester) async {
    final scroll = ScrollController(keepScrollOffset: false);
    addTearDown(scroll.dispose);
    final height = ValueNotifier(100.0);
    addTearDown(height.dispose);
    var visible = -1;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<double>(
            valueListenable: height,
            builder: (_, value, _) => ComicWebtoonView(
              controller: scroll,
              initialPage: 1,
              pageCount: 3,
              disableScale: true,
              withGap: false,
              sidePadding: 0,
              onVisibleRangeChanged: (first, last) => visible = first,
              pageBuilder: (_, index) =>
                  SizedBox(height: value, child: Text('图$index')),
              navigationBuilder: (_) =>
                  const SizedBox(height: 700, child: Text('章末')),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    height.value = 1200;
    await tester.pumpAndSettle();
    expect(visible, 1);
    expect(tester.getTopLeft(find.text('图1')).dy, 0);
    scroll.jumpTo(scroll.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(visible, 2);
    expect(tester.takeException(), isNull);
  });
}
