import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/providers/providers.dart';
import 'package:flutter_legado/src/providers/explore/explore_dependencies.dart';
import 'package:flutter_legado/src/screens/book_info_screen.dart';
import 'package:flutter_legado/src/screens/toc_screen.dart';

import '../mocks/mocks.dart';

void main() {
  setUpAll(registerFallbacks);
  late MockRustApi api;
  late BookSourceQueryServiceMock query;
  const source = BookSource(
    bookSourceUrl: 'https://source.test',
    bookSourceName: '源',
  );
  const book = Book(
    bookUrl: 'stable-book',
    originBookUrl: 'https://source.test/current',
    name: '列表书',
    origin: 'https://source.test',
    coverUrl: '',
  );
  const chapter = BookChapter(
    index: 0,
    title: '网络第一章',
    url: 'chapter',
    bookUrl: 'stable-book',
  );
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    api = MockRustApi();
    query = BookSourceQueryServiceMock();
    when(() => api.bookshelfRepository.getBook(any()))
        .thenAnswer((_) async => null);
    when(() => api.bookshelfRepository.getBooks()).thenAnswer((_) async => []);
    when(() => api.bookGroupRepository.getBookGroups())
        .thenAnswer((_) async => []);
    when(() => api.bookSourceRepository.getBookSources())
        .thenAnswer((_) async => [source]);
    when(() => api.readingRepository.getChapters(any()))
        .thenAnswer((_) async => []);
    when(() => api.getConfig(any())).thenAnswer((_) async => '');
    when(() => api.bookmarkRepository.getBookmarksByBook(any(), any()))
        .thenAnswer((_) async => []);
    when(
      () => api.highlightRepository.highlightListByBook(
        bookUrl: any(named: 'bookUrl'),
      ),
    ).thenAnswer((_) async => []);
    when(() => api.chapterCacheRepository.listCachedChapterUrls(any()))
        .thenAnswer((_) async => []);
    when(() => api.cacheDownloadService.listDownloadingChapters(any()))
        .thenAnswer((_) async => []);
    when(() => api.cacheDownloadService.listFailedChapters(any()))
        .thenAnswer((_) async => []);
  });

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1080, 2260);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookApiProvider.overrideWithValue(api),
          bookSourceQueryServiceProvider.overrideWithValue(query),
        ],
        child: MaterialApp(home: child),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('未入架详情使用当前源取址，补全目录仅展示、不写库', (tester) async {
    when(() => query.getBookInfo(source, book.originBookUrl)).thenAnswer(
      (_) async => const Book(
        name: '详情书',
        author: '详情作者',
        tocUrl: 'current-toc',
        intro: '网络简介',
      ),
    );
    when(
      () => query.getChapters(
        source,
        book.originBookUrl,
        bookUrl: book.bookUrl,
        tocUrl: 'current-toc',
        bookName: book.name,
      ),
    ).thenAnswer((_) async => [chapter]);
    await pump(tester, const BookInfoScreen(book: book));
    expect(find.text('详情作者'), findsOneWidget);
    expect(find.text('网络简介'), findsWidgets);
    verify(() => query.getBookInfo(source, book.originBookUrl)).called(1);
    verify(
      () => query.getChapters(
        source,
        book.originBookUrl,
        bookUrl: book.bookUrl,
        tocUrl: 'current-toc',
        bookName: book.name,
      ),
    ).called(1);
    verifyNever(() => api.bookshelfRepository.updateBook(any()));
    verifyNever(() => api.bookshelfRepository.addBook(any()));
    verifyNever(() => api.readingRepository.refreshToc(any(), any()));
    expect(tester.takeException(), isNull);
  });

  testWidgets('已入架详情后台合并非空字段，写回仍使用稳定主键', (tester) async {
    final stored = book.copyWith(author: '旧作者', intro: '旧简介');
    when(() => api.bookshelfRepository.getBook(book.bookUrl))
        .thenAnswer((_) async => stored);
    when(() => api.readingRepository.getChapters(book.bookUrl))
        .thenAnswer((_) async => [chapter]);
    when(() => api.bookshelfRepository.updateBook(any()))
        .thenAnswer((_) async {});
    when(() => query.getBookInfo(source, book.originBookUrl)).thenAnswer(
      (_) async => const Book(
        bookUrl: 'other-url',
        name: '刷新书',
        author: '新作者',
        intro: '新简介',
        tocUrl: 'new-toc',
      ),
    );
    await pump(tester, BookInfoScreen(book: stored));
    final updated =
        verify(() => api.bookshelfRepository.updateBook(captureAny()))
                .captured
                .single
            as Book;
    expect(updated.bookUrl, book.bookUrl);
    expect(updated.originBookUrl, book.originBookUrl);
    expect(updated.name, '刷新书');
    expect(updated.author, '新作者');
    expect(updated.intro, '新简介');
    expect(updated.tocUrl, 'new-toc');
    expect(find.text('新作者'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('详情补全失败不丢弃并行查询成功的目录', (tester) async {
    final withToc = book.copyWith(tocUrl: 'known-toc');
    when(() => query.getBookInfo(source, book.originBookUrl))
        .thenAnswer((_) async => throw const FormatException('详情格式错误'));
    when(
      () => query.getChapters(
        source,
        book.originBookUrl,
        bookUrl: book.bookUrl,
        tocUrl: 'known-toc',
        bookName: book.name,
      ),
    ).thenAnswer((_) async => [chapter]);
    await pump(tester, BookInfoScreen(book: withToc));
    expect(find.text('共 1 章'), findsOneWidget);
    expect(find.text('列表书'), findsWidgets);
    verifyNever(() => api.bookshelfRepository.updateBook(any()));
    expect(tester.takeException(), isNull);
  });

  testWidgets('未入架目录查询走独立服务，保持页面地址与章节主键区分', (tester) async {
    when(
      () => query.getChapters(
        source,
        book.originBookUrl,
        bookUrl: book.bookUrl,
        tocUrl: '',
        bookName: book.name,
      ),
    ).thenAnswer((_) async => [chapter]);
    await pump(tester, const TocScreen(book: book));
    expect(find.text('网络第一章'), findsOneWidget);
    verify(
      () => query.getChapters(
        source,
        book.originBookUrl,
        bookUrl: book.bookUrl,
        tocUrl: '',
        bookName: book.name,
      ),
    ).called(1);
    verifyNever(() => api.readingRepository.refreshToc(any(), any()));
    verifyNever(() => api.bookshelfRepository.updateBook(any()));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
