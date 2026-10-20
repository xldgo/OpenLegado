import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_legado/src/domain/models/book_detail_data.dart';
import 'package:flutter_legado/src/models/models.dart';

import '../fixtures/book_detail_fixture.dart';
import '../mocks/mocks.dart';

void main() {
  setUpAll(registerFallbacks);
  late BookDetailFixture fixture;
  setUp(() => fixture = BookDetailFixture());
  const book = BookDetailFixture.book;
  const source = BookDetailFixture.source;
  const chapter = BookDetailFixture.chapter;

  test('开读准备保留临时书标记、章节选择及媒体目录', () async {
    fixture.availableSources = [
      source.copyWith(bookSourceType: BookSourceType.audio),
    ];
    when(() => fixture.bookshelf.addBook(any())).thenAnswer((_) async => book);
    final result = await fixture.service.prepareReading(book, 3);
    expect(result.typeBits, BookType.audio);
    expect(result.book.durChapterIndex, 3);
    final stored =
        verify(() => fixture.bookshelf.addBook(captureAny())).captured.single
            as Book;
    expect(stored.bookType, BookType.audio | BookType.notShelf);
    verify(() => fixture.reading.refreshToc(book.bookUrl, book.origin))
        .called(1);
  });

  test('已有书更新媒体位时保留其他标记，不重建已有目录', () async {
    fixture.stored = book.copyWith(bookType: BookType.notShelf | BookType.text);
    fixture.cachedChapters = [chapter];
    fixture.availableSources = [
      source.copyWith(bookSourceType: BookSourceType.image),
    ];
    final result = await fixture.service.prepareReading(book, 1);
    expect(result.typeBits, BookType.image);
    final stored =
        verify(() => fixture.bookshelf.updateBook(captureAny())).captured.single
            as Book;
    expect(stored.bookType, BookType.notShelf | BookType.image);
    verifyNever(() => fixture.reading.refreshToc(any(), any()));
  });

  test('落库失败保留开读结果，书源获取失败沿用已有媒体位', () async {
    when(fixture.sources.getBookSources).thenThrow(StateError('书源失败'));
    when(() => fixture.bookshelf.getBook(any())).thenThrow(StateError('存储失败'));
    final result = await fixture.service.prepareReading(
      book.copyWith(bookType: BookType.video),
      2,
    );
    expect(result.book.durChapterIndex, 2);
    expect(result.typeBits, BookType.video);
    expect(fixture.logs, hasLength(2));
  });

  test('本地首屏先读存储，路由补全保留稳定主键和数据库抓取地址', () async {
    fixture.stored = book.copyWith(
      bookType: BookType.notShelf,
      originBookUrl: 'https://source.test/current-db',
    );
    fixture.cachedChapters = [chapter];
    final route = book.copyWith(
      author: '',
      intro: '',
      originBookUrl: 'stale-route',
    );
    final data = await fixture.service.readLocal((
      bookUrl: book.bookUrl,
      book: route,
    ));
    expect(data.book!.bookUrl, book.bookUrl);
    expect(data.book!.author, '原作者');
    expect(data.book!.originBookUrl, 'https://source.test/current-db');
    expect(data.inBookshelf, isFalse);
    expect(data.chapters, [chapter]);
    expect(data.source, source);
    verifyZeroInteractions(fixture.query);
    verifyNever(() => fixture.bookshelf.updateBook(any()));
  });

  test('本地书不查询书源或联网，返回原目录', () async {
    final local = book.copyWith(
      bookUrl: 'local.txt',
      origin: BookType.localTag,
    );
    fixture.stored = local;
    fixture.cachedChapters = [chapter];
    final data = await fixture.service.readLocal((
      bookUrl: local.bookUrl,
      book: null,
    ));
    expect(data.book, local);
    expect(data.inBookshelf, isTrue);
    expect(fixture.service.needsCompletion(data), isFalse);
    verifyZeroInteractions(fixture.sources);
    verifyZeroInteractions(fixture.query);
  });

  test('已有目录地址时并行请求详情和目录，不等待详情才能发起目录', () async {
    final info = Completer<Book>();
    final toc = Completer<List<BookChapter>>();
    when(() => fixture.query.getBookInfo(any(), any()))
        .thenAnswer((_) => info.future);
    when(
      () => fixture.query.getChapters(
        any(),
        any(),
        bookUrl: any(named: 'bookUrl'),
        tocUrl: any(named: 'tocUrl'),
        bookName: any(named: 'bookName'),
      ),
    ).thenAnswer((_) => toc.future);
    final data = BookDetailData(
      book: book.copyWith(intro: ''),
      source: source,
    );
    final pending = fixture.service
        .complete(data, isCurrent: () => true)
        .toList();
    await Future<void>.delayed(Duration.zero);
    verify(() => fixture.query.getBookInfo(source, book.originBookUrl))
        .called(1);
    verify(
      () => fixture.query.getChapters(
        source,
        book.originBookUrl,
        bookUrl: book.bookUrl,
        tocUrl: book.tocUrl,
        bookName: book.name,
      ),
    ).called(1);
    toc.complete([chapter]);
    info.complete(BookDetailFixture.fresh);
    final result = (await pending).last;
    expect(result.book!.intro, '新简介');
    expect(result.book!.bookUrl, book.bookUrl);
    expect(result.chapters, [chapter]);
    expect(result.book!.totalChapterNum, 1);
    verifyNever(() => fixture.bookshelf.updateBook(any()));
    verifyNever(() => fixture.reading.refreshToc(any(), any()));
  });

  test('详情失败仍保留并行成功目录', () async {
    when(() => fixture.query.getBookInfo(any(), any()))
        .thenThrow(const FormatException('坏详情'));
    final result =
        (await fixture.service
                .complete(
                  BookDetailData(
                    book: book.copyWith(intro: ''),
                    source: source,
                  ),
                  isCurrent: () => true,
                )
                .toList())
            .last;
    expect(result.chapters, [chapter]);
    expect(result.book!.name, book.name);
    expect(fixture.logs.single, contains('详情补全失败'));
  });

  test('目录失败仍保留独立成功的详情补全', () async {
    when(
      () => fixture.query.getChapters(
        any(),
        any(),
        bookUrl: any(named: 'bookUrl'),
        tocUrl: any(named: 'tocUrl'),
        bookName: any(named: 'bookName'),
      ),
    ).thenThrow(StateError('目录不可用'));
    final result =
        (await fixture.service
                .complete(
                  BookDetailData(
                    book: book.copyWith(intro: ''),
                    source: source,
                  ),
                  isCurrent: () => true,
                )
                .toList())
            .last;
    expect(result.book!.intro, '新简介');
    expect(result.chapters, isEmpty);
    expect(fixture.logs.single, contains('目录查询失败'));
  });

  test('已有完整元数据和目录地址只查询目录，不额外加载详情', () async {
    final data = BookDetailData(book: book, source: source, inBookshelf: true);
    final result =
        (await fixture.service.complete(data, isCurrent: () => true).toList())
            .last;
    expect(result.chapters, [chapter]);
    verifyNever(() => fixture.query.getBookInfo(any(), any()));
    verifyNever(() => fixture.reading.refreshToc(any(), any()));
    verify(() => fixture.bookshelf.updateBook(result.book!)).called(1);
  });

  for (final inShelf in [false, true]) {
    test('无目录地址先补详情，再按在架状态选择查询，inShelf=$inShelf', () async {
      final info = Completer<Book>();
      when(() => fixture.query.getBookInfo(any(), any()))
          .thenAnswer((_) => info.future);
      final updates = <BookDetailData>[];
      final done = fixture.service
          .complete(
            BookDetailData(
              book: book.copyWith(tocUrl: ''),
              source: source,
              inBookshelf: inShelf,
            ),
            isCurrent: () => true,
          )
          .forEach(updates.add);
      await Future<void>.delayed(Duration.zero);
      verifyNever(() => fixture.reading.refreshToc(any(), any()));
      verifyNever(
        () => fixture.query.getChapters(
          any(),
          any(),
          bookUrl: any(named: 'bookUrl'),
          tocUrl: any(named: 'tocUrl'),
          bookName: any(named: 'bookName'),
        ),
      );
      info.complete(BookDetailFixture.fresh);
      await done;
      expect(updates.first.book!.tocUrl, 'new-toc');
      expect(updates.first.chapters, isEmpty);
      expect(updates.last.chapters, [chapter]);
      if (inShelf) {
        verify(() => fixture.reading.refreshToc(book.bookUrl, book.origin))
            .called(1);
        verify(() => fixture.bookshelf.updateBook(updates.last.book!))
            .called(1);
      } else {
        verify(
          () => fixture.query.getChapters(
            source,
            book.originBookUrl,
            bookUrl: book.bookUrl,
            tocUrl: 'new-toc',
            bookName: book.name,
          ),
        ).called(1);
        verifyNever(() => fixture.bookshelf.updateBook(any()));
        verifyNever(() => fixture.reading.refreshToc(any(), any()));
      }
    });
  }

  test('缓存目录先显示，后台刷新非空字段写回同一稳定书籍', () async {
    final result =
        (await fixture.service
                .complete(
                  BookDetailData(
                    book: book,
                    chapters: [chapter],
                    source: source,
                    inBookshelf: true,
                  ),
                  isCurrent: () => true,
                )
                .toList())
            .last;
    expect(result.book!.name, '新书名');
    expect(result.book!.bookUrl, book.bookUrl);
    expect(result.book!.originBookUrl, book.originBookUrl);
    expect(result.chapters, [chapter]);
    verify(() => fixture.bookshelf.updateBook(result.book!)).called(1);
    verifyNever(
      () => fixture.query.getChapters(
        any(),
        any(),
        bookUrl: any(named: 'bookUrl'),
        tocUrl: any(named: 'tocUrl'),
        bookName: any(named: 'bookName'),
      ),
    );
  });

  test('后台详情失败保留缓存，不发起无效写回', () async {
    when(() => fixture.query.getBookInfo(any(), any()))
        .thenThrow(StateError('网络不可用'));
    final result =
        (await fixture.service
                .complete(
                  BookDetailData(
                    book: book,
                    chapters: [chapter],
                    source: source,
                    inBookshelf: true,
                  ),
                  isCurrent: () => true,
                )
                .toList())
            .last;
    expect(result.book, book);
    expect(result.chapters, [chapter]);
    verifyNever(() => fixture.bookshelf.updateBook(any()));
  });

  test('写回失败仍返回已成功取得的数据', () async {
    when(() => fixture.bookshelf.updateBook(any()))
        .thenThrow(StateError('写入失败'));
    final result =
        (await fixture.service
                .complete(
                  BookDetailData(
                    book: book,
                    chapters: [chapter],
                    source: source,
                    inBookshelf: true,
                  ),
                  isCurrent: () => true,
                )
                .toList())
            .last;
    expect(result.book!.name, '新书名');
    expect(fixture.logs.single, contains('更新书籍元数据失败'));
  });

  test('请求失效后不写回也不发布迟到结果', () async {
    final info = Completer<Book>();
    var current = true;
    when(() => fixture.query.getBookInfo(any(), any()))
        .thenAnswer((_) => info.future);
    final pending = fixture.service
        .complete(
          BookDetailData(
            book: book,
            chapters: [chapter],
            source: source,
            inBookshelf: true,
          ),
          isCurrent: () => current,
        )
        .toList();
    await Future<void>.delayed(Duration.zero);
    current = false;
    info.complete(BookDetailFixture.fresh);
    expect(await pending, isEmpty);
    verifyNever(() => fixture.bookshelf.updateBook(any()));
  });

  test('刷新目录按在架状态区分写入型与只读查询', () async {
    await fixture.service.refreshChapters(
      BookDetailData(book: book, source: source),
    );
    verify(
      () => fixture.query.getChapters(
        source,
        book.originBookUrl,
        bookUrl: book.bookUrl,
        tocUrl: book.tocUrl,
        bookName: book.name,
      ),
    ).called(1);
    verifyNever(() => fixture.reading.refreshToc(any(), any()));
    await fixture.service.refreshChapters(
      BookDetailData(book: book, source: source, inBookshelf: true),
    );
    verify(() => fixture.reading.refreshToc(book.bookUrl, book.origin))
        .called(1);
  });

  test('书源查询无跨页面静态缓存，编辑后下次读取使用新数据', () async {
    final service = fixture.service;
    expect(await service.findSource('${source.bookSourceUrl}/'), source);
    final updated = source.copyWith(variable: '新变量');
    fixture.availableSources = [updated];
    expect(await service.findSource(source.bookSourceUrl), updated);
    fixture.availableSources = [];
    expect(await service.findSource(source.bookSourceUrl), isNull);
  });

  test('空地址无书籍不读数据库，首次数据库失败原样上抛', () async {
    final service = fixture.service;
    final empty = await service.readLocal((bookUrl: '', book: null));
    expect(empty.book, isNull);
    verifyZeroInteractions(fixture.bookshelf);
    when(() => fixture.bookshelf.getBook(any()))
        .thenThrow(StateError('数据库不可用'));
    await expectLater(
      service.readLocal((bookUrl: book.bookUrl, book: book)),
      throwsStateError,
    );
    verifyZeroInteractions(fixture.query);
  });
}
