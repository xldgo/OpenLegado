library;

// 真实 Windows DLL：实体、类型化排版与独立取消凭据。— Codex + Bridge
@Timeout(Duration(minutes: 3))
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated_io.dart'
    show ExternalLibrary;
import 'package:flutter_legado/src/bridge/frb_generated.dart';
import 'package:flutter_legado/src/bridge/ffi/ffi.dart' as bridge;
import 'package:flutter_legado/src/bridge/ffi.dart' as requests;
import 'package:flutter_legado/src/services/reader_layout_service.dart';
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

void _golden(Object? actual, Object? expected, String path) {
  if (actual is num && expected is num) {
    expect(
      actual,
      closeTo(expected, 0.0001 + expected.abs() * 0.0000003),
      reason: path,
    );
  } else if (actual is Map && expected is Map) {
    expect(actual.keys.toSet(), expected.keys.toSet(), reason: path);
    for (final key in expected.keys) {
      _golden(actual[key], expected[key], '$path.$key');
    }
  } else if (actual is List && expected is List) {
    expect(actual.length, expected.length, reason: path);
    for (var i = 0; i < expected.length; i++) {
      _golden(actual[i], expected[i], '$path[$i]');
    }
  } else {
    expect(actual, expected, reason: path);
  }
}

void main() {
  if (!Platform.isWindows) {
    test('需要本机 DLL', () {}, skip: 'Windows 宿主测试');
    return;
  }
  late Directory root;
  setUpAll(() async {
    root = Directory(
      '.dart_tool/typed-transport-${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    await RustLib.init(
      externalLibrary: ExternalLibrary.open(
        File('../rust/target/debug/legado_ffi.dll').resolveSymbolicLinksSync(),
      ),
    );
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
  test('上游全部输入通过原生句柄，返回共享字节列可解码，完成后释放', () async {
    final fixture = jsonDecode(
      File('../rust/legado-ffi/tests/fixtures/layout_transport.json')
          .readAsStringSync(),
    ) as Map;
    final reference = jsonDecode(
      utf8.decode(
        gzip.decode(
          File('../rust/legado-layout/tests/fixtures/md3.json.gz')
              .readAsBytesSync(),
        ),
      ),
    ) as Map;
    final expected = {
      for (final c in reference['cases'] as List) c['name']: c['expected'],
    };
    for (final c in fixture['cases'] as List) {
      final input = c['input'] as Map;
      final session = ReaderLayoutSession(
        config: Map<String, Object?>.from(input['config'] as Map),
      );
      try {
        final pages = <Map<String, dynamic>>[];
        final blocks = (input['blocks'] as List)
            .map((b) => Map<String, Object?>.from(b as Map))
            .toList();
        for (var i = 0; i < blocks.length; i += 32) {
          pages.addAll(
            (await session.push(
              blocks.sublist(i, (i + 32).clamp(0, blocks.length)),
            )).pages,
          );
        }
        pages.addAll((await session.finish()).pages);
        _golden(pages, expected[c['name']], c['name'] as String);
        expect(session.closed, isTrue, reason: c['name'] as String);
      } finally {
        await session.cancel();
      }
    }
  });
  test('排版取消和完成不耗尽并发名额', () async {
    final config = <String, Object?>{
      'chapterIndex': 0,
      'chapterTitle': '测试',
      'viewportWidthPx': 320,
      'viewportHeightPx': 480,
      'paddingLeftPx': 10,
      'paddingTopPx': 10,
      'paddingRightPx': 10,
      'paddingBottomPx': 10,
      'lineHeightPx': 24,
      'baselineOffsetPx': 18,
    };
    for (var i = 0; i < 20; i++) {
      final session = ReaderLayoutSession(config: config);
      if (i.isEven) {
        await session.cancel();
        await expectLater(
          session.push([]),
          throwsA(isA<ReaderLayoutCancelled>()),
        );
      } else {
        await session.finish();
        await session.cancel();
      }
    }
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
