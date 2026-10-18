import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_legado/src/domain/contracts/book_source_query_service.dart';
import 'package:flutter_legado/src/domain/contracts/book_source_repository.dart';
import 'package:flutter_legado/src/domain/contracts/bookshelf_repository.dart';
import 'package:flutter_legado/src/domain/contracts/network_service.dart';
import 'package:flutter_legado/src/domain/contracts/search_service.dart';
import 'package:flutter_legado/src/domain/errors/app_exception.dart';
import 'package:flutter_legado/src/domain/models/http_response.dart';
import 'package:flutter_legado/src/features/bookshelf/application/bookshelf_import_controller.dart';
import 'package:flutter_legado/src/models/models.dart';

class _Shelf extends Mock implements BookshelfRepository {}

class _Sources extends Mock implements BookSourceRepository {}

class _Query extends Mock implements BookSourceQueryService {}

class _Search extends Mock implements SearchService {}

class _Network extends Mock implements NetworkService {}

void main() {
  late _Shelf shelf;
  late _Sources sources;
  late _Query query;
  late _Search search;
  late _Network network;
  late BookshelfImportController controller;
  late List<Book> currentBooks;
  late List<Book> saved;
  late List<String> logs;
  const source = BookSource(bookSourceUrl: 'https://source.test');

  setUpAll(() {
    registerFallbackValue(const Book());
    registerFallbackValue(const BookSource());
  });
  setUp(() {
    shelf = _Shelf();
    sources = _Sources();
    query = _Query();
    search = _Search();
    network = _Network();
    currentBooks = [];
    saved = [];
    logs = [];
    when(() => sources.getEnabledBookSources())
        .thenAnswer((_) async => [source]);
    when(() => shelf.addBook(any())).thenAnswer((call) async {
      final book = call.positionalArguments.single as Book;
      saved.add(book);
      return book;
    });
    when(
      () => search.preciseSearch(
        any(),
        any(),
        sourceUrls: any(named: 'sourceUrls'),
      ),
    ).thenAnswer(
      (call) async => SearchBook(
        name: call.positionalArguments[0] as String,
        author: call.positionalArguments[1] as String,
        bookUrl: 'book://${call.positionalArguments[0]}',
        origin: source.bookSourceUrl,
        tocUrl: 'toc://chapter',
        coverUrl: 'cover://image',
      ),
    );
    controller = BookshelfImportController(
      bookshelf: shelf,
      sources: sources,
      sourceQuery: query,
      search: search,
      network: network,
      currentBooks: () => currentBooks,
      log: logs.add,
    );
  });

  void expectSummary(
    BookshelfImportResult result,
    int added,
    int skipped,
    int failed,
  ) {
    expect(
      result,
      isA<BookshelfImportSummary>()
          .having((r) => r.added, '成功', added)
          .having((r) => r.skipped, '跳过', skipped)
          .having((r) => r.failed, '失败', failed),
    );
  }

  test('JSON导入按书名作者去重，成功后才计入批内去重，忽略无效条目', () async {
    currentBooks = [const Book(name: '已在架', author: '甲')];
    final result = await controller.importBookshelf(
      jsonEncode([
        {'name': '已在架', 'author': '甲'},
        {'name': ' 新书😀 ', 'author': ' 乙 '},
        {'name': '新书😀', 'author': '乙'},
        {'name': '新书😀', 'author': '丙'},
        {'name': ''},
        null,
        '不是书籍',
        {},
      ]),
    );
    expectSummary(result, 2, 2, 0);
    expect(saved.map((b) => (b.name, b.author)), [
      ('新书😀', '乙'),
      ('新书😀', '丙'),
    ]);
    expect(saved.first.tocUrl, 'toc://chapter');
    expect(saved.first.coverUrl, 'cover://image');
    verify(
      () =>
          search.preciseSearch('新书😀', '乙', sourceUrls: [source.bookSourceUrl]),
    ).called(1);
    verifyZeroInteractions(network);
    verifyZeroInteractions(query);
  });

  test('条目标量字段沿用字符串转换，空列表正常完成', () async {
    expectSummary(await controller.importBookshelf('[]'), 0, 0, 0);
    expectSummary(
      await controller.importBookshelf('[{"name":123,"author":true}]'),
      1,
      0,
      0,
    );
    expect(saved.single.name, '123');
    expect(saved.single.author, 'true');
  });

  test('无效JSON或非数组不读取书源、不搜索、不入架', () async {
    for (final input in ['', '{', '{}', 'null', '"文本"']) {
      expect(
        await controller.importBookshelf(input),
        isA<BookshelfImportInvalid>(),
      );
    }
    verifyZeroInteractions(sources);
    verifyZeroInteractions(search);
    verifyZeroInteractions(shelf);
  });

  test('URL下载完成后读取最新书架快照，响应首尾空白正常处理', () async {
    final response = Completer<HttpTextResponse>();
    when(() => network.httpGet('https://list.test'))
        .thenAnswer((_) => response.future);
    final pending = controller.importBookshelf('https://list.test');
    currentBooks = [const Book(name: '下载时入架', author: '甲')];
    response.complete(
      const HttpTextResponse(
        statusCode: 200,
        body: ' \n[{"name":"下载时入架","author":"甲"}]\n ',
      ),
    );
    expectSummary(await pending, 0, 1, 0);
    verifyZeroInteractions(search);
    verifyZeroInteractions(shelf);
  });

  test('HTTP失败保留原异常和堆栈，不误报格式错误或继续入架', () async {
    const error = AppException('连接失败');
    final stack = StackTrace.fromString('网络原始位置');
    when(() => network.httpGet('http://list.test'))
        .thenAnswer((_) => Future.error(error, stack));
    final result = await controller.importBookshelf('http://list.test');
    expect(
      result,
      isA<BookshelfImportFetchFailed>()
          .having((r) => r.error, '原因', same(error))
          .having((r) => r.stackTrace.toString(), '堆栈', stack.toString()),
    );
    verifyZeroInteractions(sources);
    verifyZeroInteractions(shelf);
  });

  test('非成功HTTP状态与响应格式错误有不同结果', () async {
    when(() => network.httpGet('https://list.test')).thenAnswer(
      (_) async => const HttpTextResponse(statusCode: 503, body: '[]'),
    );
    final failure = await controller.importBookshelf('https://list.test');
    expect(
      failure,
      isA<BookshelfImportFetchFailed>().having(
        (r) => r.error.toString(),
        '状态',
        'Bad state: HTTP 503',
      ),
    );
    when(() => network.httpGet('https://list.test')).thenAnswer(
      (_) async => const HttpTextResponse(statusCode: 200, body: '{}'),
    );
    expect(
      await controller.importBookshelf('https://list.test'),
      isA<BookshelfImportInvalid>(),
    );
    verifyZeroInteractions(shelf);
  });

  test('读取书源失败或没有启用书源仍以null范围精准搜索', () async {
    for (final fail in [true, false]) {
      when(() => sources.getEnabledBookSources()).thenAnswer((_) async {
        if (fail) throw StateError('书源读取失败');
        return [];
      });
      expectSummary(
        await controller.importBookshelf('[{"name":"无指定源"}]'),
        1,
        0,
        0,
      );
    }
    verify(() => search.preciseSearch('无指定源', '', sourceUrls: null)).called(2);
  });

  test('搜索失败和写入失败不记为已入架，后续同名条目仍能重试', () async {
    var searches = 0;
    when(
      () =>
          search.preciseSearch('重试', '', sourceUrls: any(named: 'sourceUrls')),
    ).thenAnswer((_) async {
      if (++searches == 1) throw const AppException('没有搜索结果');
      return const SearchBook(name: '重试', bookUrl: 'book://retry');
    });
    var writes = 0;
    when(() => shelf.addBook(any())).thenAnswer((call) async {
      if (++writes == 1) throw StateError('写入失败');
      final book = call.positionalArguments.single as Book;
      saved.add(book);
      return book;
    });
    final result = await controller.importBookshelf(
      jsonEncode(List.filled(4, {'name': '重试'})),
    );
    expectSummary(result, 1, 1, 2);
    expect(searches, 3);
    expect(writes, 2);
    expect(saved, hasLength(1));
    expect(logs, hasLength(2));
  });

  test('逐本串行等待入架结束后才搜索下一本', () async {
    final writing = Completer<Book>();
    final started = Completer<void>();
    when(() => shelf.addBook(any())).thenAnswer((call) {
      final book = call.positionalArguments.single as Book;
      if (book.name == '第一本') {
        started.complete();
        return writing.future;
      }
      return Future.value(book);
    });
    final pending = controller.importBookshelf(
      '[{"name":"第一本"},{"name":"第二本"}]',
    );
    await started.future;
    verifyNever(
      () => search.preciseSearch(
        '第二本',
        any(),
        sourceUrls: any(named: 'sourceUrls'),
      ),
    );
    writing.complete(const Book(name: '第一本'));
    expectSummary(await pending, 2, 0, 0);
  });

  test('网址添加按原输入URL去重，正则匹配优先于域名匹配', () async {
    const byHost = BookSource(bookSourceUrl: 'https://book.test');
    const byPattern = BookSource(
      bookSourceUrl: 'https://other.test',
      bookUrlPattern: r'/novel/',
    );
    when(() => sources.getEnabledBookSources())
        .thenAnswer((_) async => [byHost, byPattern]);
    when(() => query.getBookInfo(byPattern, 'https://book.test/novel/1'))
        .thenAnswer(
          (_) async => const Book(bookUrl: 'canonical://1', name: '详情书名'),
        );
    currentBooks = [const Book(bookUrl: 'https://already.test')];
    final result = await controller.addByUrls([
      'https://already.test',
      'https://book.test/novel/1',
      'https://book.test/novel/1',
    ], '备用名');
    expectSummary(result, 1, 2, 0);
    expect(saved.single.bookUrl, 'canonical://1');
    expect(saved.single.name, '详情书名');
    verify(() => query.getBookInfo(byPattern, 'https://book.test/novel/1'))
        .called(1);
    verifyZeroInteractions(search);
    verifyZeroInteractions(network);
  });

  test('非法正则仍能按域名匹配，未知域名使用备用名裸书入架', () async {
    const invalid = BookSource(
      bookSourceUrl: 'https://book.test/source',
      bookUrlPattern: '[',
    );
    when(() => sources.getEnabledBookSources())
        .thenAnswer((_) async => [invalid]);
    when(() => query.getBookInfo(invalid, 'https://book.test/book/1'))
        .thenAnswer((_) async => const Book(name: '域名匹配', bookUrl: 'book://1'));
    expectSummary(
      await controller.addByUrls([
        'https://book.test/book/1',
        'https://unknown.test/1',
      ], '备用名'),
      2,
      0,
      0,
    );
    expect(
      saved.last,
      const Book(
        name: '备用名',
        bookUrl: 'https://unknown.test/1',
        originName: '网页书籍',
      ),
    );
  });

  test('网址书源读取失败仍兜底，空备用名使用URL且保持开始时书架快照', () async {
    final loading = Completer<List<BookSource>>();
    when(() => sources.getEnabledBookSources())
        .thenAnswer((_) => loading.future);
    final pending = controller.addByUrls(['https://unknown.test'], '');
    currentBooks = [const Book(bookUrl: 'https://unknown.test')];
    loading.completeError(StateError('书源读取失败'));
    expectSummary(await pending, 1, 0, 0);
    expect(saved.single.name, 'https://unknown.test');
  });

  test('有匹配源但查询失败不降级裸书，后续网址正常继续', () async {
    when(() => query.getBookInfo(source, 'https://source.test/1'))
        .thenThrow(const AppException('详情失败'));
    expectSummary(
      await controller.addByUrls(['https://source.test/1', 'unknown://2'], ''),
      1,
      0,
      1,
    );
    expect(saved.single.bookUrl, 'unknown://2');
    expect(logs.single, contains('详情失败'));
  });

  test('网址入架失败后重复输入仍可重试，不错误增加跳过数', () async {
    var attempts = 0;
    when(() => shelf.addBook(any())).thenAnswer((call) async {
      if (++attempts == 1) throw StateError('写入失败');
      return call.positionalArguments.single as Book;
    });
    expectSummary(
      await controller.addByUrls([
        'unknown://1',
        'unknown://1',
        'unknown://1',
      ], ''),
      1,
      1,
      1,
    );
    expect(attempts, 2);
  });
}
