import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_legado/src/domain/contracts/bookshelf_repository.dart';
import 'package:flutter_legado/src/domain/contracts/book_source_repository.dart';
import 'package:flutter_legado/src/domain/contracts/reading_repository.dart';
import 'package:flutter_legado/src/features/reader_comic/application/comic_chapter_parser.dart';
import 'package:flutter_legado/src/features/reader_comic/application/comic_preload_service.dart';
import 'package:flutter_legado/src/features/reader_comic/application/comic_reader_controller.dart';
import 'package:flutter_legado/src/models/models.dart';

class _Shelf extends Mock implements BookshelfRepository {}

class _Sources extends Mock implements BookSourceRepository {}

class _Reading extends Mock implements ReadingRepository {}

class _Preloader extends Mock implements ComicPreloadService {}

void main() {
  late _Shelf shelf;
  late _Sources sources;
  late _Reading reading;
  late _Preloader preloader;
  late ComicReaderController controller;
  const book = Book(bookUrl: 'book', origin: 'source', durChapterPos: 1);
  const chapters = [
    BookChapter(index: 0, url: 'https://site/ch/1', title: '第一章'),
    BookChapter(index: 1, url: 'https://site/ch/2', title: '第二章'),
  ];
  const content = 'https://img/1.jpg\nhttps://img/2.jpg';

  setUpAll(() => registerFallbackValue(book));
  setUp(() {
    shelf = _Shelf();
    sources = _Sources();
    reading = _Reading();
    preloader = _Preloader();
    when(() => shelf.getBook(any())).thenAnswer((_) async => book);
    when(() => shelf.updateBook(any())).thenAnswer((_) async {});
    when(() => reading.getChapters(any())).thenAnswer((_) async => chapters);
    when(() => reading.fetchChapterContent(any(), any(), any()))
        .thenAnswer((_) async => content);
    when(() => sources.getBookSources()).thenAnswer(
      (_) async => [
        const BookSource(bookSourceUrl: 'source', header: '{"Referer":"site"}'),
      ],
    );
    when(
      () => reading.updateReadingProgress(
        bookUrl: any(named: 'bookUrl'),
        chapterIndex: any(named: 'chapterIndex'),
        chapterPos: any(named: 'chapterPos'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => preloader.preloadAdjacent(
        bookUrl: any(named: 'bookUrl'),
        chapterIndex: any(named: 'chapterIndex'),
        chapterCount: any(named: 'chapterCount'),
      ),
    ).thenAnswer((_) async {});
    controller = ComicReaderController(
      bookUrl: 'book',
      bookshelf: shelf,
      reading: reading,
      sources: sources,
      preloader: preloader,
    );
  });
  tearDown(() => controller.dispose());

  test('开书恢复章节和逻辑页，图片与书源头为只读快照', () async {
    await controller.open();
    final state = controller.state;
    expect(state.loading, false);
    expect(state.error, null);
    expect(state.chapterIndex, 0);
    expect(state.initialPage, 1);
    expect(state.imageUrls, ['https://img/1.jpg', 'https://img/2.jpg']);
    expect(state.imageHeaders, {'Referer': 'site'});
    expect(() => state.imageUrls.clear(), throwsUnsupportedError);
    expect(() => state.chapters.clear(), throwsUnsupportedError);
    expect(() => state.imageHeaders.clear(), throwsUnsupportedError);
    verify(
      () => preloader.preloadAdjacent(
        bookUrl: 'book',
        chapterIndex: 0,
        chapterCount: 2,
      ),
    ).called(1);
  });

  test('在线空目录刷新后加载，保留存储章节实体索引', () async {
    when(() => reading.getChapters('book')).thenAnswer((_) async => []);
    when(() => reading.refreshToc('book', 'source'))
        .thenAnswer((_) async => chapters);
    await controller.open();
    expect(controller.state.chapters, chapters);
    expect(controller.state.error, null);
    verify(() => reading.refreshToc('book', 'source')).called(1);
  });

  for (final origin in [BookType.localTag, '${BookType.webDavTag}test']) {
    test('$origin空目录不联网刷新', () async {
      when(() => shelf.getBook('book'))
          .thenAnswer((_) async => book.copyWith(origin: origin));
      when(() => reading.getChapters('book')).thenAnswer((_) async => []);
      await controller.open();
      expect(controller.state.error, '暂无章节');
      expect(controller.state.chapterError, false);
      verifyNever(() => reading.refreshToc(any(), any()));
    });
  }

  test('本地无URL章节沿用缓存正文与CBZ顺序', () async {
    when(() => reading.getChapters('book')).thenAnswer(
      (_) async => [const BookChapter(index: 0, url: '', title: '本地')],
    );
    when(() => reading.getChapterContent('book', 0))
        .thenAnswer((_) async => 'cbz://001.png\n cbz://002.png');
    await controller.open();
    expect(controller.state.imageUrls, ['cbz://001.png', 'cbz://002.png']);
    verifyNever(() => reading.fetchChapterContent(any(), any(), any()));
  });

  test('正文失败只重试当前章，不重新加载书籍和目录', () async {
    var calls = 0;
    when(() => reading.fetchChapterContent(any(), any(), any()))
        .thenAnswer((_) async {
          if (++calls == 1) throw StateError('章节失败');
          return content;
        });
    await controller.open();
    expect(controller.state.chapterError, true);
    expect(controller.state.error, contains('章节失败'));
    await controller.refreshChapter();
    expect(controller.state.error, null);
    expect(controller.state.chapterError, false);
    expect(controller.state.imageUrls, hasLength(2));
    verify(() => shelf.getBook('book')).called(1);
    verify(() => reading.getChapters('book')).called(1);
  });

  test('非卷章零图报错，卷章零图保留导航', () async {
    when(() => reading.fetchChapterContent(any(), any(), any()))
        .thenAnswer((_) async => '正文');
    await controller.open();
    expect(controller.state.error, '正文没有图片');
    expect(controller.state.chapterError, true);
    when(() => reading.getChapters('book'))
        .thenAnswer((_) async => [chapters.first.copyWith(isVolume: true)]);
    await controller.open();
    expect(controller.state.error, null);
    expect(controller.state.loading, false);
    expect(controller.state.chapters, hasLength(1));
  });

  test('切章先保存旧页再加载，最后保存新章零页', () async {
    final events = <String>[];
    when(
      () => reading.updateReadingProgress(
        bookUrl: any(named: 'bookUrl'),
        chapterIndex: any(named: 'chapterIndex'),
        chapterPos: any(named: 'chapterPos'),
      ),
    ).thenAnswer((invocation) async {
      events.add(
        'save:${invocation.namedArguments[#chapterIndex]}:${invocation.namedArguments[#chapterPos]}',
      );
    });
    await controller.open();
    final navigation = controller.state.navigationId;
    when(() => reading.fetchChapterContent('book', chapters[1].url, 'source'))
        .thenAnswer((_) async {
          events.add('load:1');
          return content;
        });
    await controller.goToChapter(1, currentPage: 1);
    expect(events, ['save:0:1', 'load:1', 'save:1:0']);
    expect(controller.state.chapterIndex, 1);
    expect(controller.state.initialPage, 0);
    expect(controller.state.navigationId, greaterThan(navigation));
    await controller.goToChapter(9, currentPage: 0);
    expect(events, hasLength(3));
  });

  test('进度裁到真实图片范围，保存失败不阻断阅读', () async {
    await controller.open();
    await controller.saveProgress(50);
    verify(
      () => reading.updateReadingProgress(
        bookUrl: 'book',
        chapterIndex: 0,
        chapterPos: 1,
      ),
    ).called(1);
    when(
      () => reading.updateReadingProgress(
        bookUrl: 'book',
        chapterIndex: 0,
        chapterPos: 0,
      ),
    ).thenThrow(StateError('写入失败'));
    await controller.saveProgress(-2);
    expect(controller.state.error, null);
  });

  test('换源后读取新书源头，迟到旧章不覆盖新会话', () async {
    final pending = Completer<String>();
    when(() => reading.fetchChapterContent('book', any(), any()))
        .thenAnswer((_) => pending.future);
    final old = controller.open();
    await Future<void>.delayed(Duration.zero);
    when(() => shelf.getBook('new')).thenAnswer(
      (_) async => book.copyWith(bookUrl: 'new', origin: 'new-source'),
    );
    when(() => sources.getBookSources()).thenAnswer(
      (_) async => [
        const BookSource(bookSourceUrl: 'new-source', header: 'Referer: new'),
      ],
    );
    await controller.open(bookUrl: 'new');
    pending.complete('https://img/old.jpg');
    await old;
    expect(controller.state.bookUrl, 'new');
    expect(controller.state.imageHeaders, {'Referer': 'new'});
    expect(controller.state.imageUrls, isNot(contains('https://img/old.jpg')));
  });

  test('书级设置用最新存储合并，清除覆盖不丢其他字段', () async {
    await controller.open();
    when(() => shelf.getBook('book')).thenAnswer(
      (_) async => book.copyWith(
        durChapterIndex: 1,
        readConfig: const ReadConfig(
          ttsEngine: 'system://default',
          mangaScrollMode: 2,
        ),
      ),
    );
    expect(
      await controller.updateReadConfigField('mangaScrollMode', null),
      true,
    );
    final saved =
        verify(() => shelf.updateBook(captureAny())).captured.single as Book;
    expect(saved.durChapterIndex, 1);
    expect(saved.readConfig?.ttsEngine, 'system://default');
    expect(saved.readConfig?.mangaScrollMode, null);
    expect(controller.state.book, saved);
  });

  test('书级设置保存失败保留原状态', () async {
    await controller.open();
    final original = controller.state.book;
    when(() => shelf.updateBook(any())).thenThrow(StateError('保存失败'));
    expect(
      await controller.updateReadConfigField('webtoonSidePaddingDp', 15),
      false,
    );
    expect(controller.state.book, original);
  });

  test('缺书是书级错误', () async {
    when(() => shelf.getBook('book')).thenAnswer((_) async => null);
    await controller.open();
    expect(controller.state.error, '未找到书籍信息');
    expect(controller.state.chapterError, false);
    expect(controller.state.loading, false);
  });

  test('图片正文保留相对路径、复合URL和章节封面顺序', () {
    final result = parseComicChapterImages(
      '''<img src="/image/a.jpg"><img src="b.jpg"><img src='https://img/c.jpg,{"Referer":"s"}'>''',
      chapters.first.copyWith(imgUrl: 'cover'),
    );
    expect(result, [
      'cover',
      'https://site/image/a.jpg',
      'https://site/ch/b.jpg',
      'https://img/c.jpg,{"Referer":"s"}',
    ]);
  });

  test('请求头保留JSON值转换与逐行格式', () {
    expect(parseComicImageHeaders('{"Referer":"site","n":2}'), {
      'Referer': 'site',
      'n': '2',
    });
    expect(parseComicImageHeaders('Referer: https://site\nUser-Agent: agent'), {
      'Referer': 'https://site',
      'User-Agent': 'agent',
    });
    expect(parseComicImageHeaders(''), isEmpty);
  });
}
