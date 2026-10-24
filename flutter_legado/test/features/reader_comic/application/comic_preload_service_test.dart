import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_legado/src/data/services/comic_image_decode_cache.dart';
import 'package:flutter_legado/src/domain/contracts/book_image_repository.dart';
import 'package:flutter_legado/src/domain/contracts/reading_repository.dart';
import 'package:flutter_legado/src/features/reader_comic/application/comic_preload_service.dart';
import 'package:flutter_legado/src/models/models.dart';

class _Images extends Mock implements BookImageRepository {}

class _Reading extends Mock implements ReadingRepository {}

void main() {
  late _Images images;
  late _Reading reading;
  late ComicPreloadService service;
  const book = Book(bookUrl: 'book', origin: 'source');
  const source = BookSource(bookSourceUrl: 'source');
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgYGBgAAAABQABh6FO1AAAAABJRU5ErkJggg==',
  );
  final direct = <String>[];
  Future<void> preload(
    List<String> urls, {
    int start = 0,
    int end = 99,
    Book? current = book,
    BookSource? currentSource,
    String bookUrl = 'book',
  }) => service.preloadRange(
    urls: urls,
    start: start,
    end: end,
    bookUrl: bookUrl,
    book: current,
    source: currentSource,
    precacheNetwork: (url) async => direct.add(url),
  );

  setUp(() {
    ComicImageDecodeCache.clearForTest();
    direct.clear();
    images = _Images();
    reading = _Reading();
    service = ComicPreloadService(images: images, reading: reading);
    when(() => images.getImageCache(any(), any()))
        .thenAnswer((_) async => null);
    when(() => images.fetchImageWithDecode(any(), any()))
        .thenAnswer((_) async => png);
    when(
      () => images.saveImageCache(
        bookUrl: any(named: 'bookUrl'),
        url: any(named: 'url'),
        bytes: any(named: 'bytes'),
      ),
    ).thenAnswer((_) async => true);
    when(() => reading.getChapterContentFull(any(), any()))
        .thenAnswer((_) async => '正文');
  });
  tearDown(() {
    service.dispose();
    ComicImageDecodeCache.clearForTest();
  });

  test('预载窗口裁到有效范围，同章去重，重置后允许再次预载', () async {
    await preload(['a', 'b', 'c'], start: -3, end: 1);
    await preload(['a', 'b', 'c'], start: 1, end: 9);
    expect(direct, ['a', 'b', 'c']);
    service.reset();
    await preload(['a', 'b', 'c'], start: 1, end: 1);
    expect(direct, ['a', 'b', 'c', 'b']);
    verifyZeroInteractions(images);
  });

  test('无书源的复合URL不会直连，普通网络图片保留原预载入口', () async {
    await preload([
      'https://img/a.jpg,{"Referer":"site"}',
      'https://img/b.jpg',
    ]);
    expect(direct, ['https://img/b.jpg']);
    verifyZeroInteractions(images);
  });

  test('书源图片磁盘命中不联网或重复保存，后台预载不填充整章内存', () async {
    when(() => images.getImageCache('book', 'a')).thenAnswer((_) async => png);
    await preload(['a'], currentSource: source);
    expect(ComicImageDecodeCache.get('source', 'a'), isNull);
    expect(direct, isEmpty);
    verifyNever(() => images.fetchImageWithDecode(any(), any()));
    verifyNever(
      () => images.saveImageCache(
        bookUrl: any(named: 'bookUrl'),
        url: any(named: 'url'),
        bytes: any(named: 'bytes'),
      ),
    );
  });

  test('无有效磁盘图时使用原书源JSON解码并按本书保存', () async {
    when(() => images.getImageCache('book', 'a'))
        .thenAnswer((_) async => [1, 2, 3]);
    await preload(['a'], currentSource: source);
    final json =
        verify(() => images.fetchImageWithDecode('a', captureAny()))
                .captured
                .single
            as String;
    expect(jsonDecode(json)['bookSourceUrl'], 'source');
    verify(() => images.saveImageCache(bookUrl: 'book', url: 'a', bytes: png))
        .called(1);
    expect(ComicImageDecodeCache.get('source', 'a'), isNull);
    expect(direct, isEmpty);
  });

  test('解码返回无效字节不写缓存或磁盘', () async {
    when(() => images.fetchImageWithDecode(any(), any()))
        .thenAnswer((_) async => Uint8List.fromList([1, 2, 3]));
    await preload(['a'], currentSource: source);
    expect(ComicImageDecodeCache.get('source', 'a'), isNull);
    verifyNever(
      () => images.saveImageCache(
        bookUrl: any(named: 'bookUrl'),
        url: any(named: 'url'),
        bytes: any(named: 'bytes'),
      ),
    );
  });

  test('预载及写盘失败保持静默，重置后可以再试', () async {
    when(() => images.fetchImageWithDecode(any(), any()))
        .thenThrow(StateError('网络失败'));
    await preload(['a'], currentSource: source);
    expect(ComicImageDecodeCache.get('source', 'a'), isNull);
    service.reset();
    when(() => images.fetchImageWithDecode(any(), any()))
        .thenAnswer((_) async => png);
    when(
      () => images.saveImageCache(
        bookUrl: any(named: 'bookUrl'),
        url: any(named: 'url'),
        bytes: any(named: 'bytes'),
      ),
    ).thenThrow(StateError('磁盘失败'));
    await preload(['a'], currentSource: source);
    expect(ComicImageDecodeCache.get('source', 'a'), isNull);
  });

  test('相邻章先下一章再上一章，失败不阻断后续', () async {
    final requested = <int>[];
    when(() => reading.getChapterContentFull('book', any()))
        .thenAnswer((call) async {
          final index = call.positionalArguments[1] as int;
          requested.add(index);
          if (index == 2) throw StateError('下一章失败');
          return '正文';
        });
    await service.preloadAdjacent(
      bookUrl: 'book',
      chapterIndex: 1,
      chapterCount: 3,
      nextCount: 1,
      previousCount: 1,
    );
    expect(requested, [2, 0]);
  });

  test('首尾章预载不越界', () async {
    await service.preloadAdjacent(
      bookUrl: 'book',
      chapterIndex: 0,
      chapterCount: 2,
      nextCount: 1,
      previousCount: 1,
    );
    verify(() => reading.getChapterContentFull('book', 1)).called(1);
    await service.preloadAdjacent(
      bookUrl: 'book',
      chapterIndex: 1,
      chapterCount: 2,
      nextCount: 1,
      previousCount: 1,
    );
    verify(() => reading.getChapterContentFull('book', 0)).called(1);
    await service.preloadAdjacent(
      bookUrl: 'book',
      chapterIndex: 0,
      chapterCount: 1,
      nextCount: 1,
      previousCount: 1,
    );
    verifyNoMoreInteractions(reading);
  });

  for (final dispose in [false, true]) {
    test('${dispose ? '退出' : '重置'}后不继续启动旧章节预载', () async {
      final pending = Completer<String>();
      when(() => reading.getChapterContentFull('book', 2))
          .thenAnswer((_) => pending.future);
      final work = service.preloadAdjacent(
        bookUrl: 'book',
        chapterIndex: 1,
        chapterCount: 3,
        nextCount: 1,
        previousCount: 1,
      );
      if (dispose) {
        service.dispose();
      } else {
        service.reset();
      }
      pending.complete('正文');
      await work;
      verifyNever(() => reading.getChapterContentFull('book', 0));
      if (dispose) {
        await preload(['direct']);
        expect(direct, isEmpty);
        await service.preloadAdjacent(
          bookUrl: 'book',
          chapterIndex: 0,
          chapterCount: 3,
          nextCount: 1,
          previousCount: 1,
        );
        verifyNever(() => reading.getChapterContentFull('book', 1));
      }
    });
  }
  test('图片队列最多两个任务，视口改变只重排等待项且同章不重复请求', () async {
    final started = <String>[];
    final pending = <String, Completer<void>>{};
    var active = 0, peak = 0;
    Future<void> prepare(String url) {
      started.add(url);
      active++;
      if (active > peak) peak = active;
      final done = pending[url] = Completer<void>();
      return done.future.whenComplete(() => active--);
    }

    Future<void> window(int anchor) => service.preloadRange(
      urls: ['0', '1', '2', '3', '4', '5', '6'],
      start: 0,
      end: 6,
      visibleIndex: anchor,
      bookUrl: 'book',
      book: book,
      source: null,
      precacheNetwork: prepare,
    );
    final first = window(3);
    expect(started, ['3', '4']);
    final latest = window(6);
    pending['3']!.complete();
    await Future<void>.delayed(Duration.zero);
    expect(started, ['3', '4', '6']);
    while (pending.values.any((value) => !value.isCompleted)) {
      for (final value in pending.values.toList()) {
        if (!value.isCompleted) value.complete();
      }
      await Future<void>.delayed(Duration.zero);
    }
    await Future.wait([first, latest]);
    expect(peak, 2);
    expect(started, ['3', '4', '6', '5', '2', '1', '0']);
    await window(0);
    expect(started.length, 7);
  });

  test('切换图片窗口后旧读取不再解码或写入，新书排队继续且不超并发', () async {
    final old = Completer<List<int>?>();
    when(() => images.getImageCache('book', any()))
        .thenAnswer((_) => old.future);
    final abandoned = preload(['a', 'b', 'c'], currentSource: source);
    service.reset();
    final next = preload(
      ['new'],
      current: book.copyWith(bookUrl: 'other'),
      bookUrl: 'other',
      currentSource: source,
    );
    old.complete(null);
    await Future.wait([abandoned, next]);
    verifyNever(() => images.fetchImageWithDecode('a', any()));
    verifyNever(() => images.fetchImageWithDecode('b', any()));
    verifyNever(() => images.getImageCache('book', 'c'));
    verify(
      () => images.saveImageCache(bookUrl: 'other', url: 'new', bytes: png),
    ).called(1);
  });

  test('章节数量按配置和边界展开，单章失败继续，两个零不发请求', () async {
    final requested = <int>[];
    when(() => reading.getChapterContentFull('book', any()))
        .thenAnswer((call) async {
          final index = call.positionalArguments[1] as int;
          requested.add(index);
          if (index == 3) throw StateError('暂时失败');
          return '正文';
        });
    await service.preloadAdjacent(
      bookUrl: 'book',
      chapterIndex: 2,
      chapterCount: 5,
      nextCount: 10,
      previousCount: 1,
    );
    expect(requested, [3, 4, 1]);
    await service.preloadAdjacent(
      bookUrl: 'book',
      chapterIndex: 2,
      chapterCount: 5,
      nextCount: 0,
      previousCount: 0,
    );
    expect(requested, [3, 4, 1]);
  });
}
