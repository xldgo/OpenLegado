import 'dart:convert';

import 'package:flutter_legado/src/bridge/frb_generated.dart';
import 'package:flutter_legado/src/data/repositories/rust_rss_article_repository.dart';
import 'package:flutter_legado/src/data/repositories/rust_rss_read_record_repository.dart';
import 'package:flutter_legado/src/data/repositories/rust_rss_source_repository.dart';
import 'package:flutter_legado/src/data/repositories/rust_rss_star_repository.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Bridge extends Mock implements RustLibApi {}

void main() {
  late _Bridge bridge;
  const sources = RustRssSourceRepository();
  const articles = RustRssArticleRepository();
  const records = RustRssReadRecordRepository();
  const stars = RustRssStarRepository();

  setUp(() {
    bridge = _Bridge();
    RustLib.initMock(api: bridge);
  });
  tearDown(RustLib.dispose);

  const source = RssSource(
    sourceUrl: 'https://rss.example/feed',
    sourceName: '订阅源',
    sourceGroup: '科技',
    header: '{"X-Source":"rss"}',
    ruleArticles: 'article',
    customOrder: 3,
  );

  for (final enabled in [false, true]) {
    test('启停只更新RSS实体且保留原字段：$enabled', () async {
      final current = source.copyWith(enabled: !enabled);
      when(() => bridge.crateFfiFfiRssListSources())
          .thenAnswer((_) async => jsonEncode([current.toJson()]));
      when(
        () => bridge.crateFfiFfiRssUpdateSource(
          sourceJson: any(named: 'sourceJson'),
        ),
      ).thenAnswer(
        (invocation) async => invocation.namedArguments[#sourceJson] as String,
      );

      if (enabled) {
        await sources.enableRssSource(source.sourceUrl);
      } else {
        await sources.disableRssSource(source.sourceUrl);
      }

      final payload =
          verify(
                () => bridge.crateFfiFfiRssUpdateSource(
                  sourceJson: captureAny(named: 'sourceJson'),
                ),
              ).captured.single
              as String;
      expect(
        RssSource.fromJson(jsonDecode(payload) as Map<String, dynamic>),
        current.copyWith(enabled: enabled),
      );
      verify(() => bridge.crateFfiFfiRssListSources()).called(1);
      // 任何书源表调用或额外写入都会令此断言失败。
      verifyNoMoreInteractions(bridge);
    });
  }

  test('启停源不存在时失败且不写入', () async {
    when(() => bridge.crateFfiFfiRssListSources())
        .thenAnswer((_) async => '[]');
    await expectLater(sources.disableRssSource('missing'), throwsStateError);
    verify(() => bridge.crateFfiFfiRssListSources()).called(1);
    verifyNoMoreInteractions(bridge);
  });

  test('更新拒绝false和损坏响应', () async {
    for (final payload in ['false', 'null', '[]', 'invalid']) {
      when(
        () => bridge.crateFfiFfiRssUpdateSource(
          sourceJson: any(named: 'sourceJson'),
        ),
      ).thenAnswer((_) async => payload);
      await expectLater(
        sources.updateRssSource(source),
        payload == 'false' ? throwsStateError : throwsFormatException,
      );
    }
  });

  test('新增读取真实返回值，删除透传URL', () async {
    final saved = source.copyWith(lastUpdateTime: 100);
    when(
      () =>
          bridge.crateFfiFfiRssAddSource(sourceJson: any(named: 'sourceJson')),
    ).thenAnswer((_) async => jsonEncode(saved.toJson()));
    when(() => bridge.crateFfiFfiRssDeleteSource(sourceUrl: source.sourceUrl))
        .thenAnswer((_) async {});
    expect(await sources.addRssSource(source), saved);
    final payload =
        verify(
              () => bridge.crateFfiFfiRssAddSource(
                sourceJson: captureAny(named: 'sourceJson'),
              ),
            ).captured.single
            as String;
    expect(jsonDecode(payload), source.toJson());
    await sources.deleteRssSource(source.sourceUrl);
    verify(() => bridge.crateFfiFfiRssDeleteSource(sourceUrl: source.sourceUrl))
        .called(1);
    verifyNoMoreInteractions(bridge);
  });

  test('导入沿用逐条RSS写入和非对象条目跳过，导出保持完整字段', () async {
    when(
      () =>
          bridge.crateFfiFfiRssAddSource(sourceJson: any(named: 'sourceJson')),
    ).thenAnswer(
      (invocation) async => invocation.namedArguments[#sourceJson] as String,
    );
    expect(await sources.importRssSources(jsonEncode([source.toJson(), 3])), 1);
    verify(
      () =>
          bridge.crateFfiFfiRssAddSource(sourceJson: any(named: 'sourceJson')),
    ).called(1);
    await expectLater(sources.importRssSources('{}'), throwsFormatException);
    when(() => bridge.crateFfiFfiRssListSources())
        .thenAnswer((_) async => jsonEncode([source.toJson()]));
    expect(jsonDecode(await sources.exportRssSources()), [source.toJson()]);
  });

  test('文章保留link/image与url/imageUrl两组字段，清理透传来源', () async {
    when(() => bridge.crateFfiFfiRssFetchArticles(sourceUrl: 'feed'))
        .thenAnswer(
          (_) async =>
              '[{"title":"一","link":"a","image":"i","content":"正文"},'
              '{"title":"二","url":"b","imageUrl":"j","description":"摘要"}]',
        );
    final result = await articles.getRssArticles('feed');
    expect(result.map((a) => a.url), ['a', 'b']);
    expect(result.map((a) => a.imageUrl), ['i', 'j']);
    expect(result.first.content, '正文');
    expect(result.last.description, '摘要');
    when(() => bridge.crateFfiFfiRssClearArticles(sourceUrl: 'feed'))
        .thenAnswer((_) async {});
    await articles.rssClearArticles('feed');
    verify(() => bridge.crateFfiFfiRssClearArticles(sourceUrl: 'feed'))
        .called(1);
  });

  test('已读列表在数据层解析，来源与limit透传且不重排', () async {
    const raw =
        '[{"origin":"feed","title":"后读","link":null,"read_time":200},'
        '{"origin":"feed","title":"先读","link":"a","read_time":100}]';
    when(() => bridge.crateFfiFfiRssListReadRecords(limit: 2))
        .thenAnswer((_) async => raw);
    when(
      () => bridge.crateFfiFfiRssListReadRecordsByOrigin(
        origin: 'feed',
        limit: 1,
      ),
    ).thenAnswer((_) async => raw);
    final result = await records.rssListReadRecords(2);
    expect(result.map((r) => r.readTime), [200, 100]);
    expect(result.first.link, isNull);
    expect(await records.rssListReadRecordsByOrigin('feed', 1), result);
    verify(() => bridge.crateFfiFfiRssListReadRecords(limit: 2)).called(1);
    verify(
      () => bridge.crateFfiFfiRssListReadRecordsByOrigin(
        origin: 'feed',
        limit: 1,
      ),
    ).called(1);
    verifyNoMoreInteractions(bridge);
  });

  test('已读写入、判断、数量和清空各自走既有入口', () async {
    when(
      () => bridge.crateFfiFfiRssMarkRead(
        origin: 'feed',
        title: '标题',
        link: null,
      ),
    ).thenAnswer((_) async {});
    when(() => bridge.crateFfiFfiRssIsRead(link: 'article'))
        .thenAnswer((_) async => true);
    when(() => bridge.crateFfiFfiRssIsReadByTitle(origin: 'feed', title: '标题'))
        .thenAnswer((_) async => false);
    when(() => bridge.crateFfiFfiRssReadRecordCount())
        .thenAnswer((_) async => 3);
    when(() => bridge.crateFfiFfiRssClearReadRecords())
        .thenAnswer((_) async {});
    await records.rssMarkRead('feed', '标题');
    expect(await records.rssIsRead('article'), isTrue);
    expect(await records.rssIsReadByTitle('feed', '标题'), isFalse);
    expect(await records.rssReadRecordCount(), 3);
    await records.rssClearReadRecords();
    verify(
      () => bridge.crateFfiFfiRssMarkRead(
        origin: 'feed',
        title: '标题',
        link: null,
      ),
    ).called(1);
    verify(() => bridge.crateFfiFfiRssIsRead(link: 'article')).called(1);
    verify(
      () => bridge.crateFfiFfiRssIsReadByTitle(origin: 'feed', title: '标题'),
    ).called(1);
    verify(() => bridge.crateFfiFfiRssReadRecordCount()).called(1);
    verify(() => bridge.crateFfiFfiRssClearReadRecords()).called(1);
    verifyNoMoreInteractions(bridge);
  });

  test('收藏保持既有返回实体和按link操作', () async {
    const star = RssStar(
      origin: 'feed',
      title: '标题',
      link: 'article',
      content: '正文',
    );
    when(
      () => bridge.crateFfiFfiRssStarAdd(
        sourceUrl: 'feed',
        title: '标题',
        link: 'article',
      ),
    ).thenAnswer((_) async => 100);
    when(() => bridge.crateFfiFfiRssStarIsStarred(link: 'article'))
        .thenAnswer((_) async => true);
    when(() => bridge.crateFfiFfiRssStarDelete(link: 'article'))
        .thenAnswer((_) async => false);
    when(() => bridge.crateFfiFfiRssStarList())
        .thenAnswer((_) async => jsonEncode([star.toJson()]));
    expect(await stars.addRssStar(star), star);
    expect(await stars.isStarred('article'), isTrue);
    expect(await stars.getRssStars(), [star]);
    await stars.deleteRssStar('article');
    verify(() => bridge.crateFfiFfiRssStarDelete(link: 'article')).called(1);
  });

  for (final payload in ['{}', '[null]', '[{"title":3}]', 'invalid']) {
    test('查询拒绝坏结构而非返回空结果：$payload', () async {
      when(() => bridge.crateFfiFfiRssListSources())
          .thenAnswer((_) async => payload);
      when(() => bridge.crateFfiFfiRssFetchArticles(sourceUrl: 'feed'))
          .thenAnswer((_) async => payload);
      when(() => bridge.crateFfiFfiRssListReadRecords(limit: null))
          .thenAnswer((_) async => payload);
      when(() => bridge.crateFfiFfiRssStarList())
          .thenAnswer((_) async => payload);
      // 源标题字段为sourceName；单独使用字段类型错误测试源模型。
      if (payload == '[{"title":3}]') {
        when(() => bridge.crateFfiFfiRssListSources())
            .thenAnswer((_) async => '[{"sourceName":3}]');
      }
      await expectLater(sources.getRssSources(), throwsFormatException);
      await expectLater(articles.getRssArticles('feed'), throwsFormatException);
      await expectLater(records.rssListReadRecords(), throwsFormatException);
      await expectLater(stars.getRssStars(), throwsFormatException);
    });
  }

  test('合法空列表成功，FRB异常原样传播', () async {
    when(() => bridge.crateFfiFfiRssListSources())
        .thenAnswer((_) async => '[]');
    expect(await sources.getRssSources(), isEmpty);
    final failure = StateError('数据库失败');
    when(() => bridge.crateFfiFfiRssListSources()).thenThrow(failure);
    await expectLater(sources.getRssSources(), throwsA(same(failure)));
  });
}
