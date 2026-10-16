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
  setUp(() {
    bridge = _Bridge();
    RustLib.initMock(api: bridge);
  });
  tearDown(RustLib.dispose);

  test('非流式搜索保留过滤和预拉参数、完整候选字段及Rust顺序', () async {
    when(
      () => bridge.crateFfiFfiSourceSwitchSearch(
        bookName: '书',
        author: '作者',
        sourceUrlsJson: '["s","t"]',
        optionsJson: any(named: 'optionsJson'),
      ),
    ).thenAnswer((call) async {
      expect(jsonDecode(call.namedArguments[#optionsJson] as String), {
        'loadInfo': true,
        'loadToc': true,
        'loadWordCount': true,
        'forceRefresh': true,
      });
      return jsonEncode({
        'book_name': '书',
        'author': '作者',
        'matches': [
          match.toJson(),
          match.copyWith(score: 99, bookUrl: 'other').toJson(),
        ],
      });
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

  test('默认搜索传空源列表和关闭的增强选项', () async {
    when(
      () => bridge.crateFfiFfiSourceSwitchSearch(
        bookName: '书',
        author: '',
        sourceUrlsJson: '[]',
        optionsJson: any(named: 'optionsJson'),
      ),
    ).thenAnswer((call) async {
      expect(
        (jsonDecode(call.namedArguments[#optionsJson] as String) as Map).values,
        everyElement(false),
      );
      return '{"matches":[]}';
    });
    expect(await service.searchSource('书', ''), isEmpty);
  });

  test('流式快照保留进度、错误及终批，订阅取消传递给桥接流', () async {
    var cancelled = false;
    final events = StreamController<String>(
      onCancel: () {
        cancelled = true;
      },
    );
    addTearDown(() => unawaited(events.close()));
    when(
      () => bridge.crateFfiFfiSourceSwitchSearchStream(
        bookName: '书',
        author: '作者',
        sourceUrlsJson: '["s"]',
        optionsJson: any(named: 'optionsJson'),
      ),
    ).thenAnswer((call) {
      expect(jsonDecode(call.namedArguments[#optionsJson] as String), {
        'loadInfo': true,
        'loadToc': false,
        'loadWordCount': true,
        'forceRefresh': true,
      });
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
      jsonEncode({
        'source_index': 2,
        'source_url': 's',
        'source_name': '源',
        'error': '单源失败',
        'finished_count': 3,
        'total_count': 4,
        'is_last': true,
        'matches': [match.toJson()],
      }),
    );
    final batch = await next;
    expect(batch.matches, [match]);
    expect(batch.sourceIndex, 2);
    expect(batch.sourceUrl, 's');
    expect(batch.sourceName, '源');
    expect(batch.error, '单源失败');
    expect([batch.finishedCount, batch.totalCount], [3, 4]);
    expect(batch.isLast, isTrue);
    expect(cancelled, isTrue);
    expect(() => batch.matches.clear(), throwsUnsupportedError);
  });

  for (final payload in ['[]', '{}', '{"matches":null}', '{"matches":[1]}']) {
    test('坏候选结构不冒充空结果：$payload', () async {
      when(
        () => bridge.crateFfiFfiSourceSwitchSearch(
          bookName: '书',
          author: '',
          sourceUrlsJson: '[]',
          optionsJson: any(named: 'optionsJson'),
        ),
      ).thenAnswer((_) async => payload);
      await expectLater(service.searchSource('书', ''), throwsFormatException);
    });
  }

  for (final prefetch in [false, true]) {
    test('换源预拉=$prefetch分派到独立FRB，返回完整书籍与稳定主键', () async {
      if (prefetch) {
        when(
          () => bridge.crateFfiFfiSourceSwitchApplyPrefetch(
            bookUrl: 'stable',
            newSourceUrl: 's',
            newBookUrl: 'page',
          ),
        ).thenAnswer((_) async => jsonEncode(switched.toJson()));
      } else {
        when(
          () => bridge.crateFfiFfiSourceSwitchApply(
            bookUrl: 'stable',
            newSourceUrl: 's',
            newBookUrl: 'page',
          ),
        ).thenAnswer((_) async => jsonEncode(switched.toJson()));
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

  for (final payload in [
    'not json',
    '[]',
    '{}',
    '{"bookUrl":"candidate-page"}',
  ]) {
    test('坏换源结果不回退候选地址：$payload', () async {
      when(
        () => bridge.crateFfiFfiSourceSwitchApplyPrefetch(
          bookUrl: 'stable',
          newSourceUrl: 's',
          newBookUrl: 'page',
        ),
      ).thenAnswer((_) async => payload);
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
