import 'package:flutter_legado/src/data/services/book_detail_service.dart';
import 'package:flutter_legado/src/domain/contracts/bookshelf_repository.dart';
import 'package:flutter_legado/src/domain/contracts/book_source_repository.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';

class DetailBookshelf extends Mock implements BookshelfRepository {}

class DetailSources extends Mock implements BookSourceRepository {}

/// 各窄依赖都可独立控制完成时机，不访问原生或网络。— Codex + UI
class BookDetailFixture {
  static const source = BookSource(
    bookSourceUrl: 'https://source.test',
    bookSourceName: '源',
  );
  static const book = Book(
    bookUrl: 'stable-book',
    originBookUrl: 'https://source.test/current',
    name: '原书名',
    author: '原作者',
    origin: 'https://source.test',
    tocUrl: 'known-toc',
    coverUrl: 'old-cover',
    intro: '原简介',
  );
  static const chapter = BookChapter(
    bookUrl: 'stable-book',
    index: 0,
    title: '第一章',
    url: 'chapter-0',
  );
  static const fresh = Book(
    bookUrl: 'network-address',
    name: '新书名',
    author: '新作者',
    coverUrl: 'new-cover',
    intro: '新简介',
    tocUrl: 'new-toc',
  );

  final bookshelf = DetailBookshelf();
  final sources = DetailSources();
  final reading = ReadingRepositoryMock();
  final query = BookSourceQueryServiceMock();
  final logs = <String>[];
  Book? stored;
  List<BookChapter> cachedChapters = [];
  List<BookSource> availableSources = [source];

  BookDetailFixture() {
    when(() => bookshelf.getBook(any())).thenAnswer((_) async => stored);
    when(() => bookshelf.updateBook(any())).thenAnswer((_) async {});
    when(() => reading.getChapters(any()))
        .thenAnswer((_) async => cachedChapters);
    when(() => reading.refreshToc(any(), any()))
        .thenAnswer((_) async => [chapter]);
    when(sources.getBookSources).thenAnswer((_) async => availableSources);
    when(() => query.getBookInfo(any(), any())).thenAnswer((_) async => fresh);
    when(
      () => query.getChapters(
        any(),
        any(),
        bookUrl: any(named: 'bookUrl'),
        tocUrl: any(named: 'tocUrl'),
        bookName: any(named: 'bookName'),
      ),
    ).thenAnswer((_) async => [chapter]);
  }

  BookDetailService get service => BookDetailService(
    bookshelf: bookshelf,
    reading: reading,
    sources: sources,
    query: query,
    log: logs.add,
  );
}
