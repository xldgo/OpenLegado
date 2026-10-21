import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_legado/src/features/rules/application/subscriptions/rule_sub_import_service.dart';
import 'package:flutter_legado/src/domain/models/http_response.dart';
import 'package:flutter_legado/src/domain/models/source_preview.dart';
import 'package:flutter_legado/src/models/models.dart';

import '../mocks/mocks.dart';

void main() {
  setUpAll(registerFallbacks);
  late NetworkServiceMock network;
  late RssSourceRepositoryMock rss;
  late ReplaceRuleRepositoryMock rules;
  late RuleSubImportService service;
  const url = 'https://test/sub';
  setUp(() {
    network = NetworkServiceMock();
    rss = RssSourceRepositoryMock();
    rules = ReplaceRuleRepositoryMock();
    service = RuleSubImportService(
      network: network,
      rss: rss,
      replaceRules: rules,
      fetchBookSources: (_) async => [
        SourcePreview.fromNormalized({'bookSourceUrl': url}, {'bookSourceUrl': url}),
      ],
    );
    when(() => rss.getRssSources()).thenAnswer((_) async => []);
    when(() => rules.getReplaceRules()).thenAnswer((_) async => []);
  });
  void response(String body, [int status = 200]) {
    when(
      () => network.httpGet(url, timeout: const Duration(seconds: 30)),
    ).thenAnswer((_) async => HttpTextResponse(statusCode: status, body: body));
  }

  test('RSS对象与数组保持原始字段，过滤非对象条目', () async {
    response('{"sourceUrl":"abc","custom":42}');
    final first = await service.prepare(
      const RuleSub(url: url, subType: RuleSub.rssSource),
    ) as RuleSubRssSources;
    expect(first.items.single['custom'], 42);
    response('[null,4,{"sourceUrl":"abc"}]');
    final next = await service.prepare(
      const RuleSub(url: url, subType: RuleSub.rssSource),
    ) as RuleSubRssSources;
    expect(next.items, hasLength(1));
    expect(() => next.items.clear(), throwsUnsupportedError);
  });
  test('替换规则本地读取失败仍保留原有空快照回退', () async {
    response('[{"id":1}]');
    when(() => rules.getReplaceRules()).thenThrow(StateError('读取失败'));
    final result = await service.prepare(
      const RuleSub(url: url, subType: RuleSub.replaceRule),
    ) as RuleSubReplaceRules;
    expect(result.items.single['id'], 1);
    expect(result.local, isEmpty);
    verifyNever(() => rss.getRssSources());
  });
  test('书源使用既有导入服务并固定开始时的本地快照', () async {
    final fetch = Completer<List<SourcePreview>>();
    service = RuleSubImportService(
      network: network,
      rss: rss,
      replaceRules: rules,
      fetchBookSources: (_) => fetch.future,
    );
    final local = [const BookSource(bookSourceUrl: 'a', bookSourceName: '旧')];
    final task = service.prepare(
      const RuleSub(url: url),
      localBookSources: local,
    );
    local.clear();
    fetch.complete([
      SourcePreview.fromNormalized({'bookSourceUrl': url}, {'bookSourceUrl': url}),
    ]);
    final result = await task as RuleSubBookSources;
    expect(result.local.single.bookSourceUrl, 'a');
    expect(result.items.single.bookSourceUrl, url);
    verifyZeroInteractions(network);
  });
  test('HTTP失败、非法JSON、错误根类型及未知订阅类型向上传递', () async {
    const sub = RuleSub(url: url, subType: RuleSub.rssSource);
    response('oops', 503);
    await expectLater(service.prepare(sub), throwsA(isA<Exception>()));
    response('{bad');
    await expectLater(service.prepare(sub), throwsFormatException);
    response('42');
    await expectLater(service.prepare(sub), throwsFormatException);
    await expectLater(
      service.prepare(sub.copyWith(subType: 'unknown')),
      throwsFormatException,
    );
  });
}
