import 'dart:convert';

import 'package:flutter_legado/src/bridge/task_dto.dart';
import 'package:flutter_legado/src/bridge/ffi.dart' as controls;

import 'package:flutter_legado/src/bridge/content_dto.dart';
import 'package:flutter_legado/src/bridge/transfer_dto.dart';
import 'package:flutter_legado/src/data/bridge/entity_dto_mapping.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_legado/src/bridge/frb_generated.dart';
import 'package:flutter_legado/src/data/repositories/rust_explore_state_repository.dart';
import 'package:flutter_legado/src/data/services/rust_explore_service.dart';
import 'package:flutter_legado/src/data/services/rust_book_source_query_service.dart';
import 'package:flutter_legado/src/data/services/rust_book_source_debug_service.dart';
import 'package:flutter_legado/src/models/models.dart';

class _Bridge extends Mock implements RustLibApi {}

class _Request extends Fake implements controls.StreamRequest {
  @override
  void cancel() {}
  @override
  void dispose() {}
}

void main() {
  late _Bridge bridge;
  const source = BookSource(
    bookSourceUrl: 'https://source.test/root/',
    bookSourceName: '测试源',
    header: '{"token":"token"}',
    ruleBookInfo: BookInfoRule(name: 'h1'),
  );
  final sourceJson = jsonEncode(source.toJson());
  const explore = RustExploreService();
  const query = RustBookSourceQueryService();
  const state = RustExploreStateRepository();
  const debug = RustBookSourceDebugService();
  setUpAll(() {
    registerFallbackValue(_Request());
    registerFallbackValue(bookSourceToDto(source));
  });
  setUp(() {
    bridge = _Bridge();
    RustLib.initMock(api: bridge);
    when(() => bridge.crateFfiStreamRequestNew()).thenReturn(_Request());
  });
  tearDown(RustLib.dispose);
  test('分类保留控件、空选项过滤、全部Flex样式与可空书源', () async {
    when(
      () => bridge.crateFfiFfiExploreParseUrl(
        exploreUrl: '@js:categories()',
        source: any(named: 'source'),
      ),
    ).thenAnswer(
      (_) async => [
        const ExploreCategoryDto(
          title: '类型',
          url: null,
          kind: 'toggle',
          action: 'refreshExplore()',
          chars: ['男', null, '', '女'],
          defaultValue: '女',
          viewName: '标题JS',
          style: FlexChildStyleDto(
            layoutFlexGrow: 2,
            layoutFlexShrink: 0,
            layoutAlignSelf: 'center',
            layoutFlexBasisPercent: 1,
            layoutWrapBefore: true,
            layoutJustifySelf: 'end',
          ),
        ),
      ],
    );
    when(
      () => bridge.crateFfiFfiExploreParseUrl(
        exploreUrl: '分类::/list',
        source: null,
      ),
    ).thenAnswer(
      (_) async => [
        const ExploreCategoryDto(
          title: '分类',
          url: '/list',
          kind: 'url',
          action: null,
          chars: null,
          defaultValue: null,
          viewName: null,
          style: null,
        ),
      ],
    );
    final c = (await explore.parseCategories(
      '@js:categories()',
      source: source,
    )).single;
    expect(c.title, '类型');
    expect(c.type, 'toggle');
    expect(c.chars, ['男', '女']);
    expect(c.defaultValue, '女');
    expect(c.action, 'refreshExplore()');
    expect(c.viewName, '标题JS');
    expect(c.style!.layoutFlexGrow, 2);
    expect(c.style!.layoutFlexShrink, 0);
    expect(c.style!.layoutAlignSelf, 'center');
    expect(c.style!.layoutFlexBasisPercent, 1);
    expect(c.style!.layoutWrapBefore, true);
    expect(c.style!.layoutJustifySelf, 'end');
    expect((await explore.parseCategories('分类::/list')).single.url, '/list');
    final v =
        verify(
              () => bridge.crateFfiFfiExploreParseUrl(
                exploreUrl: '@js:categories()',
                source: captureAny(named: 'source'),
              ),
            ).captured.single
            as BookSourceDto;
    expect(v.bookSourceUrl, source.bookSourceUrl);
    expect(v.header, source.header);
    expect(v.ruleBookInfo!.name, 'h1');
  });
  test('发现保留URL补全、当前源名称、空链接及书籍类型', () async {
    when(
      () => bridge.crateFfiFfiExploreFetchBooks(
        source: any(named: 'source'),
        url: '/rank',
        page: 3,
      ),
    ).thenAnswer(
      (_) async => [
        _search('../book/1', '//images.test/1', 64, ''),
        _search(
          '/book/2',
          'data:image/png;base64,AQ==',
          32,
          'https://other.test',
        ),
        _search('', null, 0, ''),
      ],
    );
    final books = await explore.fetchBooks(source, '/rank', 3);
    expect(books[0].bookUrl, 'https://source.test/book/1');
    expect(books[0].coverUrl, 'https://images.test/1');
    expect(books[0].origin, source.bookSourceUrl);
    expect(books[0].originName, source.bookSourceName);
    expect(books[0].wordCount, '10万');
    expect(books[0].latestChapterTitle, '最新章');
    expect(books[0].bookType, 64);
    expect(books[1].bookUrl, 'https://other.test/book/2');
    expect(books[1].coverUrl, startsWith('data:'));
    expect(books[1].bookType, 32);
    expect(books[2].bookUrl, '');
    expect(books[2].coverUrl, isNull);
  });
  test('详情与目录直接消费实体快照，保留当前书源和稳定章节归属', () async {
    when(
      () => bridge.crateFfiFfiWebbookInfo(
        source: any(named: 'source'),
        bookUrl: 'page',
      ),
    ).thenAnswer(
      (_) async => const WebBookInfoDto(
        name: '详情',
        author: '作者',
        coverUrl: 'cover',
        intro: '简介',
        categories: ['小说'],
        lastChapter: '最新章',
        bookUrl: 'resolved',
        tocUrl: 'toc',
        wordCount: '20万',
        kind: '小说',
        variable: '{"v":1}',
        bookType: 64,
      ),
    );
    final book = await query.getBookInfo(source, 'page');
    expect(book.bookUrl, 'resolved');
    expect(book.origin, source.bookSourceUrl);
    expect(book.originName, source.bookSourceName);
    expect(book.bookType, 64);
    expect(book.coverUrl, 'cover');
    expect(book.kind, '小说');
    expect(book.wordCount, '20万');
    expect(book.latestChapterTitle, '最新章');
    expect(book.tocUrl, 'toc');
    expect(book.variable, '{"v":1}');
    when(
      () => bridge.crateFfiFfiWebbookChapters(
        source: any(named: 'source'),
        bookUrl: 'page',
        tocUrl: 'toc',
        bookName: '书',
      ),
    ).thenAnswer(
      (_) async => [
        const WebChapterDto(
          index: 4,
          title: '卷一',
          url: 'chapter',
          isVip: true,
          isVolume: true,
          variable: '{"k":"v"}',
          wordCount: '1万',
        ),
      ],
    );
    final chapter = (await query.getChapters(
      source,
      'page',
      bookUrl: 'stable',
      tocUrl: 'toc',
      bookName: '书',
    )).single;
    expect(chapter.bookUrl, 'stable');
    expect(chapter.index, 4);
    expect(chapter.title, '卷一');
    expect(chapter.isVip, true);
    expect(chapter.isVolume, true);
    expect(chapter.wordCount, '1万');
    expect(chapter.variable, '{"k":"v"}');
  });
  test('动作返回类型化外壳，内部平台动作仍为脚本协议文档', () async {
    when(
      () => bridge.crateFfiFfiExploreEvalAction(
        sourceJson: sourceJson,
        actionJs: 'run()',
      ),
    ).thenAnswer(
      (_) async => const ExploreActionDto(
        raw: 'ok',
        actionsJson: '[{"action":"copyText","text":"文字"}]',
        refreshExplore: true,
      ),
    );
    when(
      () => bridge.crateFfiFfiExploreEvalUiJs(
        sourceJson: sourceJson,
        jsStr: 'title()',
      ),
    ).thenAnswer((_) async => '值');
    final result = await explore.evaluateAction(
      sourceJson: sourceJson,
      actionJs: 'run()',
    );
    expect(result.raw, 'ok');
    expect(result.actions.single, {'action': 'copyText', 'text': '文字'});
    expect(result.refreshExplore, true);
    expect(() => result.actions.clear(), throwsUnsupportedError);
    expect(
      await explore.evaluateUiJs(sourceJson: sourceJson, jsStr: 'title()'),
      '值',
    );
  });
  test('类型化空结果合法，底层错误仍上抛', () async {
    when(
      () => bridge.crateFfiFfiExploreFetchBooks(
        source: any(named: 'source'),
        url: 'u',
        page: 1,
      ),
    ).thenAnswer((_) async => []);
    when(
      () => bridge.crateFfiFfiWebbookChapters(
        source: any(named: 'source'),
        bookUrl: 'b',
        tocUrl: '',
        bookName: '',
      ),
    ).thenAnswer((_) async => []);
    expect(await explore.fetchBooks(source, 'u', 1), isEmpty);
    expect(await query.getChapters(source, 'b', bookUrl: 'stable'), isEmpty);
    final error = StateError('解析失败');
    when(
      () => bridge.crateFfiFfiWebbookInfo(
        source: any(named: 'source'),
        bookUrl: 'b',
      ),
    ).thenThrow(error);
    await expectLater(query.getBookInfo(source, 'b'), throwsA(same(error)));
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
        .thenAnswer((_) async => {'k': 'v', '空': ''});
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

  test('调试流映射状态与文本，沿用原生取消', () async {
    when(
      () => bridge.crateFfiFfiDebugBookSourceStream(
        sourceUrl: 's',
        key: 'k',
        request: any(named: 'request'),
      ),
    ).thenAnswer(
      (_) => Stream.fromIterable([
        const DebugLogDto(state: 1, msg: '开始'),
        const DebugLogDto(state: -1, msg: '失败'),
        const DebugLogDto(state: 1000, msg: '完成'),
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

  test('调试流原生异常向上传递', () async {
    final error = StateError('原生调试失败');
    when(
      () => bridge.crateFfiFfiDebugBookSourceStream(
        sourceUrl: 'error',
        key: 'k',
        request: any(named: 'request'),
      ),
    ).thenAnswer((_) => Stream.error(error));
    await expectLater(debug.debug('error', 'k'), emitsError(same(error)));
  });
}

WebSearchResultDto _search(
  String url,
  String? cover,
  int type,
  String origin,
) => WebSearchResultDto(
  name: '书',
  author: '作者',
  bookUrl: url,
  coverUrl: cover,
  intro: '简介',
  latestChapter: '最新章',
  sourceUrl: origin,
  kind: '小说',
  wordCount: '10万',
  bookType: type,
);
