@Tags(['native'])
@Timeout(Duration(minutes: 3))
library;

// 真实宿主原生库：实体、类型化排版与独立取消凭据。— Codex + Bridge
import '../helpers/native_ffi.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/bridge/frb_generated.dart';
import 'package:flutter_legado/src/bridge/ffi/ffi.dart' as bridge;
import 'package:flutter_legado/src/bridge/ffi.dart' as requests;
import 'package:flutter_legado/src/data/repositories/rust_bookshelf_repository.dart';
import 'package:flutter_legado/src/data/bridge/entity_dto_mapping.dart';
import 'package:flutter_legado/src/bridge/transfer_dto.dart';
import 'package:flutter_legado/src/data/bridge/managed_rust_stream.dart';
import 'package:flutter_legado/src/models/book.dart';
import 'package:flutter_legado/src/models/book_source.dart';
import 'package:flutter_legado/src/data/services/rust_search_service.dart';
import 'package:flutter_legado/src/data/services/rust_source_checker.dart';
import 'package:flutter_legado/src/data/services/rust_source_switch_service.dart';
import 'package:flutter_legado/src/data/repositories/rust_reading_repository.dart';

import 'package:flutter_legado/src/data/services/rust_network_service.dart';
import 'package:flutter_legado/src/data/services/rust_book_source_query_service.dart';
import 'package:flutter_legado/src/data/services/rust_explore_service.dart';
import 'package:flutter_legado/src/data/services/rust_review_service.dart';

void main() {
  late Directory root;
  setUpAll(() async {
    root = Directory(
      '.dart_tool/typed-transport-${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    await RustLib.init(externalLibrary: nativeTestLibrary());
    await bridge.init();
    await bridge.dbOpen(path: '${root.absolute.path}/data.db');
  });
  tearDownAll(() async {
    RustLib.dispose();
  });
  test('类型化实体经 wire 与数据库往返，更新保留主键与嵌套字段', () async {
    const repo = RustBookshelfRepository();
    const book = Book(
      bookUrl: 'https://example.test/书😀',
      name: '小说😀',
      author: '作者',
      group: 9007199254740993,
      origin: 'https://example.test',
      durChapterIndex: 4,
      durChapterPos: 11,
      readConfig: ReadConfig(
        ttsEngine: 'system://default',
        playSpeed: 1.7,
        closeCredits: 9,
      ),
    );
    final saved = await repo.addBook(book);
    expect(saved.bookUrl, book.bookUrl);
    expect(saved.group, book.group);
    expect(
      saved.readConfig!.playSpeed,
      closeTo(book.readConfig!.playSpeed, 0.000001),
    );
    expect(
      saved.readConfig!.copyWith(playSpeed: book.readConfig!.playSpeed),
      book.readConfig,
    );
    await repo.updateBook(saved.copyWith(name: '更新'));
    final read = await repo.getBook(book.bookUrl);
    expect(read!.name, '更新');
    expect(
      read.readConfig!.playSpeed,
      closeTo(book.readConfig!.playSpeed, 0.000001),
    );
    expect(
      read.readConfig!.copyWith(playSpeed: book.readConfig!.playSpeed),
      book.readConfig,
    );
    expect((await repo.getBooks()).single.bookUrl, book.bookUrl);
    expect(await repo.getBook('missing'), isNull);
    final source = BookSource.fromJson({
      'bookSourceUrl': 'https://typed.test',
      'bookSourceName': '书源😀',
      'header': '{"X-Test":"yes"}',
      'jsLib': 'var x=1;',
      'concurrentRate': '2/1000',
      'ruleSearch': {'bookList': 'div', 'name': 'h1', 'bookUrl': 'a@href'},
      'enabledCookieJar': false,
    });
    final added = bookSourceFromDto(
      await bridge.sourceAdd(source: bookSourceToDto(source)),
    );
    expect(added, source);
    await bridge.sourceUpdate(
      source: bookSourceToDto(added.copyWith(bookSourceName: '改名')),
    );
    final sources = await bridge.sourceList();
    expect(sources.single.bookSourceName, '改名');
    expect(bookSourceFromDto(sources.single).ruleSearch, source.ruleSearch);
  });
  test('旧订阅取消后新校验流仍输出类型化进度', () async {
    await bridge.sourceAdd(
      source: bookSourceToDto(
        const BookSource(
          bookSourceUrl: 'https://missing-new.test',
          bookSourceName: '新校验源',
        ),
      ),
    );
    final old = managedRustStream(
      (request) => bridge.sourceCheckStream(
        sourceUrls: ['missing-old'],
        config: const SourceCheckConfigDto(),
        request: request,
      ),
    ).listen((_) {});
    final next = managedRustStream(
      (request) => bridge.sourceCheckStream(
        sourceUrls: ['https://missing-new.test'],
        config: const SourceCheckConfigDto(),
        request: request,
      ),
    ).toList();
    await old.cancel();
    final events = await next.timeout(const Duration(seconds: 10));
    expect(events, isNotEmpty);
    expect(
      events.any(
        (event) => event.result.sourceUrl == 'https://missing-new.test',
      ),
      isTrue,
    );
    expect(events.last.isLast, isTrue);
  });
  test('尚无搜索事件时，句柄取消能关闭等待中的真实 HTTP 搜索流', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final entered = Completer<void>(),
        release = Completer<void>(),
        done = Completer<void>();
    server.listen((request) async {
      if (!entered.isCompleted) entered.complete();
      await release.future;
      try {
        request.response.write('<div>迟到正文</div>');
        await request.response.close();
      } catch (_) {}
    });
    final url = 'http://127.0.0.1:${server.port}';
    await bridge.sourceAdd(
      source: bookSourceToDto(
        BookSource.fromJson({
          'bookSourceUrl': url,
          'bookSourceName': '等待搜索源',
          'searchUrl': '$url/search?key={{key}}',
          'ruleSearch': {
            'bookList': 'tag.div',
            'name': 'text',
            'bookUrl': 'text',
          },
        }),
      ),
    );
    final request = requests.streamRequestNew();
    final events = <Object>[];
    final subscription = bridge
        .searchMultiStream(
          query: '小说',
          sourceUrls: [url],
          page: 1,
          request: request,
        )
        .listen(events.add, onDone: done.complete, onError: done.completeError);
    try {
      await entered.future.timeout(const Duration(seconds: 10));
      expect(events, isEmpty);
      request.cancel();
      await done.future.timeout(const Duration(seconds: 3));
      expect(events, isEmpty);
    } finally {
      release.complete();
      await subscription.cancel();
      request.dispose();
      await server.close(force: true);
    }
  });
  test('剩余搜索、校验、目录刷新与换源事务经真实类型化wire完成', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final base = 'http://127.0.0.1:${server.port}';
    final subscription = server.listen((request) async {
      if (request.uri.path == '/redirect') {
        await request.response.redirect(Uri.parse('$base/bytes'));
        return;
      }
      if (request.uri.path == '/bytes') {
        expect(request.headers.value('x-check'), 'bytes');
        request.response.add(List.generate(256, (i) => i));
        await request.response.close();
        return;
      }
      if (request.method == 'POST') {
        request.response.write(await utf8.decoder.bind(request).join());
        await request.response.close();
        return;
      }
      if (request.uri.path == '/review') {
        request.response.headers.contentType = ContentType.json;
        request.response.write('{"data":[{"idx":1,"cnt":5}]}');
        await request.response.close();
        return;
      }
      request.response.headers.contentType = ContentType.html;
      request.response.write(switch (request.uri.path) {
        '/search' =>
          "<div class='book'><a href='$base/book'>类型化小说</a><span class='author'>测试作者</span></div>",
        '/book' =>
          "<h1>类型化小说</h1><span class='author'>测试作者</span><a class='toc' href='$base/toc'>目录</a>",
        '/toc' => "<div class='chapter'><a href='$base/chapter'>第一章</a></div>",
        '/chapter' => "<div class='content'>真实正文😀，不经过JSON包装。</div>",
        _ => 'not found',
      });
      await request.response.close();
    });
    try {
      final source = BookSource.fromJson({
        'bookSourceUrl': base,
        'bookSourceName': '类型化源',
        'customOrder': 7,
        'searchUrl': '$base/search?keyword={{key}}',
        'ruleSearch': {
          'bookList': 'class.book',
          'name': 'tag.a@text',
          'author': 'class.author@text',
          'bookUrl': 'tag.a@href',
        },
        'ruleBookInfo': {
          'name': 'tag.h1@text',
          'author': 'class.author@text',
          'tocUrl': 'class.toc@href',
        },
        'ruleToc': {
          'chapterList': 'class.chapter',
          'chapterName': 'tag.a@text',
          'chapterUrl': 'tag.a@href',
        },
        'ruleContent': {'content': 'class.content@text'},
      });
      await bridge.sourceAdd(source: bookSourceToDto(source));
      const network = RustNetworkService();
      final binary = await network.httpGetBytes(
        '$base/redirect',
        headers: {'x-check': 'bytes'},
      );
      expect(binary.bytes, List.generate(256, (i) => i));
      expect(binary.url, '$base/bytes');
      expect(binary.statusCode, 200);
      expect((await network.httpPost('$base/post', '正文😀')).body, '正文😀');
      expect((await network.httpGet('$base/book')).body, contains('类型化小说'));
      const query = RustBookSourceQueryService();
      final info = await query.getBookInfo(source, '$base/book');
      expect(info.name, '类型化小说');
      expect(info.origin, base);
      expect(
        (await query.getChapters(
          source,
          '$base/book',
          bookUrl: 'stable',
        )).single.bookUrl,
        'stable',
      );
      final exploreSource = BookSource.fromJson({
        ...source.toJson(),
        'ruleExplore': source.toJson()['ruleSearch'],
      });
      const explore = RustExploreService();
      expect(
        (await explore.parseCategories(
          '分类::$base/search',
          source: source,
        )).single.title,
        '分类',
      );
      expect(
        (await explore.fetchBooks(
          exploreSource,
          '$base/search',
          1,
        )).single.name,
        '类型化小说',
      );
      final reviewSource = BookSource.fromJson({
        ...source.toJson(),
        'ruleReview': {
          'enabled': true,
          'reviewSummaryUrl': '$base/review',
          'summaryListRule': r'$.data',
          'summaryParagraphIndexRule': r'$.idx',
          'summaryCountRule': r'$.cnt',
        },
      });
      const reviews = RustReviewService();
      expect(
        (await reviews.reviewGetSummary(jsonEncode(reviewSource.toJson()), {
          'chapterUrl': '$base/chapter',
        })).counts,
        {1: 5},
      );
      final jsReview = BookSource(
        bookSourceUrl: base,
        mainJs: r'function getReviewDetail(chapter,book,paraIndex,paraData,page) { return JSON.stringify({items:[{id:"c1",content:paraData+":"+paraIndex,replies:[{id:"r1",content:"回复"}]}],nextPageUrl:page<2?"more":null}); }',
      );
      final reviewPage = await reviews.reviewGetDetail(
        jsonEncode(jsReview.toJson()),
        {'paraIndex': 3, 'paraData': '内容😀'},
        1,
      );
      expect(reviewPage.items.single.content, '内容😀:3');
      expect(reviewPage.items.single.replies.single.content, '回复');
      expect(reviewPage.nextPageUrl, 'more');

      const search = RustSearchService();
      final found = await search.searchBooks('类型化小说', sourceUrls: [base]);
      expect(found.single.book.name, '类型化小说');
      expect(found.single.book.originOrder, 7);
      final precise = await search.preciseSearch(
        '类型化小说',
        '测试作者',
        sourceUrls: [base],
      );
      expect(precise.bookUrl, '$base/book');
      final multi = await search.searchMulti('类型化小说', sourceUrls: [base]);
      expect(multi.single['book_name'], '类型化小说');
      expect(multi.single['originOrder'], 7);
      final checked = await const RustSourceChecker().checkSource(
        source,
        configJson: '{"keyword":"类型化小说"}',
      );
      expect(checked['source_url'], base);
      expect(checked['search_ok'], true);
      expect(checked['toc_ok'], true, reason: checked.toString());
      expect(checked['content_ok'], true, reason: checked.toString());
      const shelf = RustBookshelfRepository();
      await shelf.addBook(
        Book(
          bookUrl: '$base/book',
          tocUrl: '$base/toc',
          name: '类型化小说',
          author: '测试作者',
          origin: base,
          originName: '类型化源',
        ),
      );
      final reader = RustReadingRepository(
        dispatchAction: (_) async => throw StateError('普通正文不能触发平台动作'),
      );
      final chapters = await reader.refreshToc('$base/book', base);
      expect(chapters.single.title, '第一章');
      expect(chapters.single.bookUrl, '$base/book');
      expect(
        await reader.getChapterContentFull('$base/book', 0),
        contains('真实正文😀'),
      );
      expect(
        await reader.fetchChapterContent('$base/book', '$base/chapter', base),
        contains('真实正文😀'),
      );
      const switching = RustSourceSwitchService();
      final matches = await switching.searchSource(
        '类型化小说',
        '测试作者',
        sourceUrls: [base],
        forceRefresh: true,
        loadInfo: true,
        loadToc: true,
      );
      expect(matches.single.bookUrl, '$base/book');
      final switched = await switching.switchSourcePrefetch(
        '$base/book',
        base,
        '$base/book',
      );
      expect(switched.bookUrl, '$base/book');
      expect(switched.origin, base);
      final direct = await switching.switchSource(
        '$base/book',
        base,
        '$base/book',
      );
      expect(direct.bookUrl, '$base/book');
      expect(
        (await reader.getChapters('$base/book')).single.url,
        '$base/chapter',
      );
    } finally {
      await subscription.cancel();
      await server.close(force: true);
    }
  });
}
