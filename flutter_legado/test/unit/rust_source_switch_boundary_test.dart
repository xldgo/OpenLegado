import 'package:flutter_legado/src/bridge/ffi.dart' show StreamRequest;
import 'package:flutter_legado/src/bridge/transfer_dto.dart';
import 'package:flutter_legado/src/data/bridge/entity_dto_mapping.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_legado/src/bridge/frb_generated.dart';
import 'package:flutter_legado/src/data/services/rust_source_switch_service.dart';
import 'package:flutter_legado/src/data/services/rust_cover_search_service.dart';
import 'package:flutter_legado/src/data/repositories/rust_cover_rule_repository.dart';
import 'package:flutter_legado/src/domain/models/cover_rule.dart';
import 'package:flutter_legado/src/models/models.dart';

class _Bridge extends Mock implements RustLibApi {}

class _StreamRequest extends Mock implements StreamRequest {}

SourceMatchDto _dto(SourceMatch v) => SourceMatchDto(
  sourceUrl: v.sourceUrl,
  sourceName: v.sourceName,
  bookUrl: v.bookUrl,
  bookName: v.bookName,
  author: v.author,
  latestChapter: v.latestChapter,
  wordCount: v.wordCount,
  score: v.score,
  chapterWordCountText: v.chapterWordCountText,
  chapterWordCount: v.chapterWordCount,
  respondTime: v.respondTime,
  originOrder: v.originOrder,
  bookScore: v.bookScore,
  variable: null,
);
Map<String, bool> _options(SwitchSearchOptionsDto v) => {
  'loadInfo': v.loadInfo,
  'loadToc': v.loadToc,
  'loadWordCount': v.loadWordCount,
  'forceRefresh': v.forceRefresh,
};
void main() {
  late _Bridge bridge;
  const service = RustSourceSwitchService();
  const covers = RustCoverSearchService();
  const rules = RustCoverRuleRepository();
  const match = SourceMatch(
    sourceUrl: 's',
    sourceName: '源',
    bookUrl: 'page',
    bookName: '书',
    author: '作者',
    score: 72,
    bookScore: -1,
    chapterWordCountText: '2千字',
    chapterWordCount: 2000,
    respondTime: 123,
    originOrder: 4,
  );
  const switched = Book(
    bookUrl: 'stable',
    name: '书',
    origin: 's',
    originName: '源',
    originBookUrl: 'page',
    tocUrl: 'toc',
    durChapterIndex: 7,
    durChapterPos: 123,
    variable: '{"token":"value"}',
    readConfig: ReadConfig(pageAnim: 1),
  );
  setUpAll(() {
    registerFallbackValue(_StreamRequest());
    registerFallbackValue(
      const SwitchSearchOptionsDto(
        loadInfo: false,
        loadToc: false,
        loadWordCount: false,
        forceRefresh: false,
      ),
    );
  });
  setUp(() {
    bridge = _Bridge();
    RustLib.initMock(api: bridge);
    when(() => bridge.crateFfiStreamRequestNew()).thenReturn(_StreamRequest());
  });
  tearDown(RustLib.dispose);

  test('非流式搜索按类型透传选项，保留完整候选与Rust顺序', () async {
    when(
      () => bridge.crateFfiFfiSourceSwitchSearch(
        bookName: '书',
        author: '作者',
        sourceUrls: ['s', 't'],
        options: any(named: 'options'),
      ),
    ).thenAnswer((call) async {
      expect(
        _options(call.namedArguments[#options] as SwitchSearchOptionsDto),
        {
          'loadInfo': true,
          'loadToc': true,
          'loadWordCount': true,
          'forceRefresh': true,
        },
      );
      return SourceSwitchResponseDto(
        bookName: '书',
        author: '作者',
        matches: [
          _dto(match),
          _dto(match.copyWith(score: 99, bookUrl: 'other')),
        ],
      );
    });
    final result = await service.searchSource(
      '书',
      '作者',
      sourceUrls: ['s', 't'],
      loadInfo: true,
      loadToc: true,
      loadWordCount: true,
      forceRefresh: true,
    );
    expect(result.first, match);
    expect(result.last.score, 99);
  });
  test('默认搜索传空源列表与显式关闭选项，合法空候选正常返回', () async {
    when(
      () => bridge.crateFfiFfiSourceSwitchSearch(
        bookName: '书',
        author: '',
        sourceUrls: [],
        options: any(named: 'options'),
      ),
    ).thenAnswer((call) async {
      expect(
        _options(call.namedArguments[#options] as SwitchSearchOptionsDto)
            .values,
        everyElement(false),
      );
      return const SourceSwitchResponseDto(
        bookName: '书',
        author: '',
        matches: [],
      );
    });
    expect(await service.searchSource('书', ''), isEmpty);
  });
  test('流式快照保留进度与单源错误，取消传给原流', () async {
    var cancelled = false;
    final events = StreamController<ChangeSourceBatchDto>(
      onCancel: () {
        cancelled = true;
      },
    );
    addTearDown(() => unawaited(events.close()));
    when(
      () => bridge.crateFfiFfiSourceSwitchSearchStream(
        bookName: '书',
        author: '作者',
        sourceUrls: ['s'],
        options: any(named: 'options'),
        request: any(named: 'request'),
      ),
    ).thenAnswer((call) {
      expect(
        _options(call.namedArguments[#options] as SwitchSearchOptionsDto),
        {
          'loadInfo': true,
          'loadToc': false,
          'loadWordCount': true,
          'forceRefresh': true,
        },
      );
      return events.stream;
    });
    final next = service
        .searchSourceStream(
          '书',
          '作者',
          sourceUrls: ['s'],
          loadInfo: true,
          loadWordCount: true,
          forceRefresh: true,
        )
        .first;
    events.add(
      ChangeSourceBatchDto(
        sourceIndex: BigInt.from(2),
        sourceUrl: 's',
        sourceName: '源',
        error: '单源失败',
        finishedCount: BigInt.from(3),
        totalCount: BigInt.from(4),
        isLast: true,
        matches: [_dto(match)],
      ),
    );
    final batch = await next;
    expect(batch.matches, [match]);
    expect(batch.sourceIndex, 2);
    expect(batch.error, '单源失败');
    expect([batch.finishedCount, batch.totalCount], [3, 4]);
    expect(batch.isLast, true);
    expect(cancelled, true);
    expect(() => batch.matches.clear(), throwsUnsupportedError);
  });
  test('原生候选查询失败不回退为空结果', () async {
    final error = StateError('查询失败');
    when(
      () => bridge.crateFfiFfiSourceSwitchSearch(
        bookName: '书',
        author: '',
        sourceUrls: [],
        options: any(named: 'options'),
      ),
    ).thenThrow(error);
    await expectLater(service.searchSource('书', ''), throwsA(same(error)));
  });
  for (final prefetch in [false, true]) {
    test('换源预拉=$prefetch分派正确入口并保留完整书籍', () async {
      if (prefetch) {
        when(
          () => bridge.crateFfiFfiSourceSwitchApplyPrefetch(
            bookUrl: 'stable',
            newSourceUrl: 's',
            newBookUrl: 'page',
          ),
        ).thenAnswer((_) async => bookToDto(switched));
      } else {
        when(
          () => bridge.crateFfiFfiSourceSwitchApply(
            bookUrl: 'stable',
            newSourceUrl: 's',
            newBookUrl: 'page',
          ),
        ).thenAnswer((_) async => bookToDto(switched));
      }
      final book = prefetch
          ? await service.switchSourcePrefetch('stable', 's', 'page')
          : await service.switchSource('stable', 's', 'page');
      expect(book, switched);
      if (prefetch) {
        verifyNever(
          () => bridge.crateFfiFfiSourceSwitchApply(
            bookUrl: 'stable',
            newSourceUrl: 's',
            newBookUrl: 'page',
          ),
        );
      }
    });
  }
  for (final id in ['', 'candidate-page']) {
    test('类型化结果的错误主键$id仍被拒绝', () async {
      when(
        () => bridge.crateFfiFfiSourceSwitchApplyPrefetch(
          bookUrl: 'stable',
          newSourceUrl: 's',
          newBookUrl: 'page',
        ),
      ).thenAnswer((_) async => bookToDto(switched.copyWith(bookUrl: id)));
      await expectLater(
        service.switchSourcePrefetch('stable', 's', 'page'),
        throwsFormatException,
      );
    });
  }

  test('取消、评分与删除使用原FRB参数', () async {
    when(() => bridge.crateFfiFfiSourceSwitchApplyCancel())
        .thenAnswer((_) async {});
    when(
      () => bridge.crateFfiFfiUpdateSearchBookScore(
        bookUrl: 'candidate',
        score: -1,
      ),
    ).thenAnswer((_) async {});
    when(() => bridge.crateFfiFfiDeleteSearchBook(bookUrl: 'candidate'))
        .thenAnswer((_) async {});
    await service.cancelSwitchSourceApply();
    await service.updateSearchBookScore('candidate', -1);
    await service.deleteSearchBook('candidate');
    verify(() => bridge.crateFfiFfiSourceSwitchApplyCancel()).called(1);
    verify(
      () => bridge.crateFfiFfiUpdateSearchBookScore(
        bookUrl: 'candidate',
        score: -1,
      ),
    ).called(1);
    verify(() => bridge.crateFfiFfiDeleteSearchBook(bookUrl: 'candidate'))
        .called(1);
  });

  test('封面候选与规则搜索分别解码尺寸和地址列表', () async {
    when(() => bridge.crateFfiFfiSearchCover(bookName: '书')).thenAnswer(
      (_) async => '[{"url":"a","width":240,"height":320},{"url":"b"}]',
    );
    when(() => bridge.crateFfiFfiSearchCoverRules(name: '书'))
        .thenAnswer((_) async => '["a","b"]');
    final result = await covers.searchCover('书');
    expect(result, [
      const CoverCandidate(url: 'a', width: 240, height: 320),
      const CoverCandidate(url: 'b'),
    ]);
    expect(await covers.searchCoverRules('书'), ['a', 'b']);
  });

  test('封面规则读写保留Cookie选项，删除false不冒充成功', () async {
    when(() => bridge.crateFfiFfiGetCoverRule()).thenAnswer(
      (_) async => '{"enable":false,"searchUrl":"url","coverRule":"rule","enabledCookieJar":true}',
    );
    when(
      () => bridge.crateFfiFfiSaveCoverRule(ruleJson: any(named: 'ruleJson')),
    ).thenAnswer((call) async {
      expect(jsonDecode(call.namedArguments[#ruleJson] as String), {
        'enable': false,
        'searchUrl': 'url',
        'coverRule': 'rule',
        'enabledCookieJar': true,
      });
      return true;
    });
    when(() => bridge.crateFfiFfiDeleteCoverRule())
        .thenAnswer((_) async => false);
    final rule = await rules.getCoverRule();
    expect(rule.enabledCookieJar, isTrue);
    expect(await rules.saveCoverRule(rule), isTrue);
    expect(await rules.deleteCoverRule(), isFalse);
  });

  test('未指定Cookie选项不会在写入时凭空启用', () async {
    when(
      () => bridge.crateFfiFfiSaveCoverRule(ruleJson: any(named: 'ruleJson')),
    ).thenAnswer((call) async {
      expect(jsonDecode(call.namedArguments[#ruleJson] as String), {
        'enable': true,
        'searchUrl': 'u',
        'coverRule': 'r',
      });
      return false;
    });
    expect(
      await rules.saveCoverRule(
        const CoverRule(searchUrl: 'u', coverRule: 'r'),
      ),
      isFalse,
    );
  });

  test('封面坏响应与原生失败向上传递', () async {
    when(() => bridge.crateFfiFfiSearchCover(bookName: '书'))
        .thenAnswer((_) async => '[1]');
    when(() => bridge.crateFfiFfiSearchCoverRules(name: '书'))
        .thenAnswer((_) async => '[null]');
    when(() => bridge.crateFfiFfiGetCoverRule()).thenAnswer((_) async => '[]');
    final error = StateError('事务失败');
    when(
      () => bridge.crateFfiFfiSourceSwitchApply(
        bookUrl: 'stable',
        newSourceUrl: 's',
        newBookUrl: 'page',
      ),
    ).thenThrow(error);
    await expectLater(covers.searchCover('书'), throwsFormatException);
    await expectLater(covers.searchCoverRules('书'), throwsFormatException);
    await expectLater(rules.getCoverRule(), throwsFormatException);
    await expectLater(
      service.switchSource('stable', 's', 'page'),
      throwsA(same(error)),
    );
  });
}
