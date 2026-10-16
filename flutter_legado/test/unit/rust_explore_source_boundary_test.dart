import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_legado/src/bridge/frb_generated.dart';
import 'package:flutter_legado/src/data/repositories/rust_explore_state_repository.dart';
import 'package:flutter_legado/src/data/services/rust_explore_service.dart';
import 'package:flutter_legado/src/data/services/rust_book_source_query_service.dart';
import 'package:flutter_legado/src/data/services/rust_book_source_debug_service.dart';
import 'package:flutter_legado/src/models/models.dart';

class _Bridge extends Mock implements RustLibApi {}

void main() {
  late _Bridge bridge;
  const source = BookSource(
    bookSourceUrl: 'https://source.test/root/',
    bookSourceName: '测试源',
    header: '{"token":"token"}',
    ruleBookInfo: BookInfoRule(name: 'h1'),
  );
  final sourceJson = jsonEncode(source.toJson());
  final intercepted = <String>[];
  Future<String> intercept(String raw) async {
    intercepted.add(raw);
    return raw;
  }

  late RustExploreService explore;
  late RustBookSourceQueryService query;
  const state = RustExploreStateRepository();
  const debug = RustBookSourceDebugService();
  setUp(() {
    bridge = _Bridge();
    RustLib.initMock(api: bridge);
    intercepted.clear();
    explore = RustExploreService(interceptResult: intercept);
    query = RustBookSourceQueryService(interceptResult: intercept);
  });
  tearDown(RustLib.dispose);

  test('分类将完整书源交给Rust，保留动态布局字段及无书源调用', () async {
    const expression = '@js:categories()';
    when(
      () => bridge.crateFfiFfiExploreParseUrl(
        exploreUrl: expression,
        sourceJson: sourceJson,
      ),
    ).thenAnswer(
      (_) async => '[{"title":"类型","type":"toggle","chars":["男","女"],"default":"女","action":"refreshExplore()","style":{"layout_flexBasisPercent":1}}]',
    );
    when(
      () => bridge.crateFfiFfiExploreParseUrl(
        exploreUrl: '分类::/list',
        sourceJson: '',
      ),
    ).thenAnswer((_) async => '[{"title":"分类","url":"/list"}]');
    final category = (await explore.parseCategories(
      expression,
      source: source,
    )).single;
    expect(category.title, '类型');
    expect(category.type, 'toggle');
    expect(category.chars, ['男', '女']);
    expect(category.defaultValue, '女');
    expect(category.action, 'refreshExplore()');
    expect(category.style!.layoutFlexBasisPercent, 1);
    expect((await explore.parseCategories('分类::/list')).single.url, '/list');
  });

  test('发现分页归一化URL、别名和类型位，保留空链接', () async {
    when(
      () => bridge.crateFfiFfiExploreFetchBooks(
        sourceJson: sourceJson,
        url: '/rank',
        page: 3,
      ),
    ).thenAnswer(
      (_) async => jsonEncode([
        {
          'book_url': '../book/1',
          'cover_url': '//images.test/1',
          'name': '书',
          'word_count': '10万',
          'latest_chapter': '最新章',
          'toc_url': '/toc',
          'type': 64,
        },
        {
          'bookUrl': '/book/2',
          'origin': 'https://other.test',
          'originName': '结果源',
          'coverUrl': 'data:image/png;base64,AQ==',
          'type': '32',
        },
        {'name': '没有地址'},
      ]),
    );
    final books = await explore.fetchBooks(source, '/rank', 3);
    expect(books[0].bookUrl, 'https://source.test/book/1');
    expect(books[0].coverUrl, 'https://images.test/1');
    expect(books[0].origin, source.bookSourceUrl);
    expect(books[0].originName, source.bookSourceName);
    expect(books[0].wordCount, '10万');
    expect(books[0].latestChapterTitle, '最新章');
    expect(books[0].tocUrl, '/toc');
    expect(books[0].bookType, 64);
    expect(books[1].bookUrl, 'https://other.test/book/2');
    expect(books[1].originName, '结果源');
    expect(books[1].coverUrl, startsWith('data:'));
    expect(books[1].bookType, 32);
    expect(books[2].bookUrl, '');
    expect(books[2].coverUrl, isNull);
    expect(intercepted, hasLength(1));
  });

  test('平台拦截先于发现、详情及目录解码', () async {
    const payload = '{"action":"webView","url":"https://source.test"}';
    when(
      () => bridge.crateFfiFfiExploreFetchBooks(
        sourceJson: sourceJson,
        url: '/rank',
        page: 1,
      ),
    ).thenAnswer((_) async => payload);
    when(
      () => bridge.crateFfiFfiWebbookInfo(
        sourceJson: sourceJson,
        bookUrl: 'page',
      ),
    ).thenAnswer((_) async => payload);
    when(
      () => bridge.crateFfiFfiWebbookChapters(
        sourceJson: sourceJson,
        bookUrl: 'page',
        tocUrl: '',
        bookName: '',
      ),
    ).thenAnswer((_) async => payload);
    final replies = [
      '[{"name":"发现"}]',
      '{"name":"详情"}',
      '[{"title":"目录","index":2}]',
    ].iterator;
    Future<String> replay(String raw) async {
      expect(raw, payload);
      expect(replies.moveNext(), isTrue);
      return replies.current;
    }

    expect(
      (await RustExploreService(
        interceptResult: replay,
      ).fetchBooks(source, '/rank', 1)).single.name,
      '发现',
    );
    final replayQuery = RustBookSourceQueryService(interceptResult: replay);
    expect((await replayQuery.getBookInfo(source, 'page')).name, '详情');
    final chapter = (await replayQuery.getChapters(
      source,
      'page',
      bookUrl: 'stable',
    )).single;
    expect(chapter.title, '目录');
    expect(chapter.bookUrl, 'stable');
  });

  test('详情解码snake_case字段，书源身份和类型位不丢失', () async {
    when(
      () => bridge.crateFfiFfiWebbookInfo(
        sourceJson: sourceJson,
        bookUrl: 'https://current.test/9',
      ),
    ).thenAnswer(
      (_) async => '{"book_url":"https://resolved.test/9","name":"详情","author":"作者","cover_url":"cover","intro":"简介","word_count":"20万","last_chapter":"第三章","toc_url":"toc","kind":"小说","type":64}',
    );
    final book = await query.getBookInfo(source, 'https://current.test/9');
    expect(book.bookUrl, 'https://resolved.test/9');
    expect(book.origin, source.bookSourceUrl);
    expect(book.originName, source.bookSourceName);
    expect(book.coverUrl, 'cover');
    expect(book.wordCount, '20万');
    expect(book.latestChapterTitle, '第三章');
    expect(book.tocUrl, 'toc');
    expect(book.bookType, 64);
    expect(book.kind, '小说');
    expect(book.intro, '简介');
  });

  test('详情缺省地址使用请求页面，camelCase字段保持原值', () async {
    when(
      () => bridge.crateFfiFfiWebbookInfo(
        sourceJson: sourceJson,
        bookUrl: 'page',
      ),
    ).thenAnswer(
      (_) async => '{"name":"书","coverUrl":"c","wordCount":"w","latestChapterTitle":"l","tocUrl":"t"}',
    );
    final book = await query.getBookInfo(source, 'page');
    expect(book.bookUrl, 'page');
    expect(
      [book.coverUrl, book.wordCount, book.latestChapterTitle, book.tocUrl],
      ['c', 'w', 'l', 't'],
    );
    expect(book.bookType, 0);
  });

  test('目录用当前页面抓取，章节归属稳定主键并保留收费/分卷字段', () async {
    when(
      () => bridge.crateFfiFfiWebbookChapters(
        sourceJson: sourceJson,
        bookUrl: 'current-page',
        tocUrl: 'current-toc',
        bookName: '书',
      ),
    ).thenAnswer(
      (_) async => '[{"index":4,"title":"卷一","url":"chapter","bookUrl":"wrong","is_volume":true,"is_vip":true,"is_pay":true,"resource_url":"audio"}]',
    );
    final chapter = (await query.getChapters(
      source,
      'current-page',
      bookUrl: 'stable-book',
      tocUrl: 'current-toc',
      bookName: '书',
    )).single;
    expect(chapter.bookUrl, 'stable-book');
    expect(chapter.index, 4);
    expect(chapter.url, 'chapter');
    expect(chapter.isVolume, isTrue);
    expect(chapter.isVip, isTrue);
    expect(chapter.isPay, isTrue);
    expect(chapter.resourceUrl, 'audio');
  });

  test('动作返回独立只读结果，UI脚本保持原文传入与返回', () async {
    when(
      () => bridge.crateFfiFfiExploreEvalAction(
        sourceJson: sourceJson,
        actionJs: 'run()',
      ),
    ).thenAnswer(
      (_) async => '{"raw":"ok","actions":[{"action":"copyText","text":"文字"}],"refreshExplore":true}',
    );
    when(
      () => bridge.crateFfiFfiExploreEvalUiJs(
        sourceJson: sourceJson,
        jsStr: 'infoMap.get("选项")',
      ),
    ).thenAnswer((_) async => '值');
    final result = await explore.evaluateAction(
      sourceJson: sourceJson,
      actionJs: 'run()',
    );
    expect(result.raw, 'ok');
    expect(result.actions.single, {'action': 'copyText', 'text': '文字'});
    expect(result.refreshExplore, isTrue);
    expect(() => result.actions.clear(), throwsUnsupportedError);
    expect(
      await explore.evaluateUiJs(
        sourceJson: sourceJson,
        jsStr: 'infoMap.get("选项")',
      ),
      '值',
    );
  });

  test('infoMap读写沿用Rust状态与字符串值', () async {
    when(
      () => bridge.crateFfiFfiExploreInfoMapPut(
        sourceUrl: 's',
        key: 'k',
        value: 'v',
      ),
    ).thenAnswer((_) async {});
    when(
      () => bridge.crateFfiFfiExploreInfoMapEnsureDefault(
        sourceUrl: 's',
        key: 'k',
        defaultValue: 'd',
      ),
    ).thenAnswer((_) async {});
    when(() => bridge.crateFfiFfiExploreInfoMapSnapshot(sourceUrl: 's'))
        .thenAnswer((_) async => '{"k":"v","空":""}');
    await state.put('s', 'k', 'v');
    await state.ensureDefault('s', 'k', 'd');
    expect(await state.snapshot('s'), {'k': 'v', '空': ''});
    verify(
      () => bridge.crateFfiFfiExploreInfoMapPut(
        sourceUrl: 's',
        key: 'k',
        value: 'v',
      ),
    ).called(1);
    verify(
      () => bridge.crateFfiFfiExploreInfoMapEnsureDefault(
        sourceUrl: 's',
        key: 'k',
        defaultValue: 'd',
      ),
    ).called(1);
  });

  for (final payload in ['[]', '{"k":null}', '{"k":3}']) {
    test('错误infoMap不会当作空快照：$payload', () async {
      when(() => bridge.crateFfiFfiExploreInfoMapSnapshot(sourceUrl: 's'))
          .thenAnswer((_) async => payload);
      await expectLater(state.snapshot('s'), throwsFormatException);
    });
  }

  test('坏列表和目录元素不能当作查询成功', () async {
    when(
      () => bridge.crateFfiFfiExploreParseUrl(exploreUrl: 'u', sourceJson: ''),
    ).thenAnswer((_) async => '{}');
    when(
      () => bridge.crateFfiFfiExploreFetchBooks(
        sourceJson: sourceJson,
        url: 'u',
        page: 1,
      ),
    ).thenAnswer((_) async => '{}');
    when(
      () => bridge.crateFfiFfiWebbookInfo(sourceJson: sourceJson, bookUrl: 'b'),
    ).thenAnswer((_) async => '[]');
    when(
      () => bridge.crateFfiFfiWebbookChapters(
        sourceJson: sourceJson,
        bookUrl: 'b',
        tocUrl: '',
        bookName: '',
      ),
    ).thenAnswer((_) async => '[1]');
    await expectLater(explore.parseCategories('u'), throwsFormatException);
    await expectLater(
      explore.fetchBooks(source, 'u', 1),
      throwsFormatException,
    );
    await expectLater(query.getBookInfo(source, 'b'), throwsFormatException);
    await expectLater(
      query.getChapters(source, 'b', bookUrl: 'stable'),
      throwsFormatException,
    );
  });

  test('调试流映射状态与文本，沿用原生取消', () async {
    when(
      () => bridge.crateFfiFfiDebugBookSourceStream(sourceUrl: 's', key: 'k'),
    ).thenAnswer(
      (_) => Stream.fromIterable([
        '{"state":1,"msg":"开始"}',
        '{"state":-1,"msg":"失败"}',
        '{"state":1000,"msg":"完成"}',
      ]),
    );
    when(() => bridge.crateFfiFfiDebugBookSourceCancel())
        .thenAnswer((_) async {});
    final events = await debug.debug('s', 'k').toList();
    expect(events.map((e) => e.state), [1, -1, 1000]);
    expect(events.map((e) => e.message), ['开始', '失败', '完成']);
    await debug.cancel();
    verify(() => bridge.crateFfiFfiDebugBookSourceCancel()).called(1);
  });

  test('调试流格式错误及原生异常向上传递', () async {
    when(
      () => bridge.crateFfiFfiDebugBookSourceStream(sourceUrl: 'bad', key: 'k'),
    ).thenAnswer((_) => Stream.value('[]'));
    final error = StateError('原生调试失败');
    when(
      () =>
          bridge.crateFfiFfiDebugBookSourceStream(sourceUrl: 'error', key: 'k'),
    ).thenAnswer((_) => Stream.error(error));
    await expectLater(
      debug.debug('bad', 'k'),
      emitsError(isA<FormatException>()),
    );
    await expectLater(debug.debug('error', 'k'), emitsError(same(error)));
  });

  test('查询及动作异常不替换成空结果', () async {
    final error = StateError('解析失败');
    when(
      () => bridge.crateFfiFfiWebbookInfo(sourceJson: sourceJson, bookUrl: 'b'),
    ).thenThrow(error);
    when(
      () => bridge.crateFfiFfiExploreEvalAction(
        sourceJson: sourceJson,
        actionJs: 'run()',
      ),
    ).thenThrow(error);
    await expectLater(query.getBookInfo(source, 'b'), throwsA(same(error)));
    await expectLater(
      explore.evaluateAction(sourceJson: sourceJson, actionJs: 'run()'),
      throwsA(same(error)),
    );
  });
}
