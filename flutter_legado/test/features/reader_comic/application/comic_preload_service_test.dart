import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_legado/src/data/services/comic_image_decode_cache.dart';
import 'package:flutter_legado/src/domain/contracts/book_image_repository.dart';
import 'package:flutter_legado/src/domain/contracts/local_book_service.dart';
import 'package:flutter_legado/src/domain/contracts/reading_repository.dart';
import 'package:flutter_legado/src/features/reader_comic/application/comic_preload_service.dart';
import 'package:flutter_legado/src/models/models.dart';

class _Images extends Mock implements BookImageRepository {}

class _LocalBooks extends Mock implements LocalBookService {}

class _Reading extends Mock implements ReadingRepository {}

void main() {
  late _Images images;
  late _LocalBooks localBooks;
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
    localBooks = _LocalBooks();
    reading = _Reading();
    service = ComicPreloadService(
      images: images,
      localBooks: localBooks,
      reading: reading,
    );
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
    when(
      () => localBooks.cbzReadPage(
        path: any(named: 'path'),
        entry: any(named: 'entry'),
      ),
    ).thenAnswer((_) async => png);
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
    verifyZeroInteractions(localBooks);
  });

  test('无书源的复合URL不会直连，普通网络图片保留原预载入口', () async {
    await preload([
      'https://img/a.jpg,{"Referer":"site"}',
      'https://img/b.jpg',
    ]);
    expect(direct, ['https://img/b.jpg']);
    verifyZeroInteractions(images);
  });

  test('书源图片磁盘命中填入共享缓存，不访问网络或重复保存', () async {
    when(() => images.getImageCache('book', 'a')).thenAnswer((_) async => png);
    await preload(['a'], currentSource: source);
    expect(ComicImageDecodeCache.get('source', 'a'), png);
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
    expect(ComicImageDecodeCache.get('source', 'a'), png);
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

  test('CBZ优先走本地服务，内存命中复用，不同书同名条目隔离', () async {
    await preload(['cbz://001.png'], currentSource: source);
    service.reset();
    await preload(['cbz://001.png']);
    verify(() => localBooks.cbzReadPage(path: 'book', entry: 'cbz://001.png'))
        .called(1);
    service.reset();
    await preload(
      ['cbz://001.png'],
      current: book.copyWith(bookUrl: 'other'),
      bookUrl: 'other',
    );
    verify(() => localBooks.cbzReadPage(path: 'other', entry: 'cbz://001.png'))
        .called(1);
    expect(ComicImageDecodeCache.get('book', 'cbz://001.png'), png);
    expect(ComicImageDecodeCache.get('other', 'cbz://001.png'), png);
    verifyZeroInteractions(images);
    expect(direct, isEmpty);
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
    expect(ComicImageDecodeCache.get('source', 'a'), png);
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
    );
    expect(requested, [2, 0]);
  });

  test('首尾章预载不越界', () async {
    await service.preloadAdjacent(
      bookUrl: 'book',
      chapterIndex: 0,
      chapterCount: 2,
    );
    verify(() => reading.getChapterContentFull('book', 1)).called(1);
    await service.preloadAdjacent(
      bookUrl: 'book',
      chapterIndex: 1,
      chapterCount: 2,
    );
    verify(() => reading.getChapterContentFull('book', 0)).called(1);
    await service.preloadAdjacent(
      bookUrl: 'book',
      chapterIndex: 0,
      chapterCount: 1,
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
        );
        verifyNever(() => reading.getChapterContentFull('book', 1));
      }
    });
  }
}
