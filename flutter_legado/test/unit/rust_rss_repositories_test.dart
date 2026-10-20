import '../fixtures/business_transport_fixtures.dart';

import 'package:flutter_legado/src/data/bridge/business_dto_mapping.dart';
import 'package:flutter_legado/src/bridge/business_dto.dart';

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

  setUpAll(() => registerFallbackValue(rssSourceToDto(const RssSource())));
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
      when(() => bridge.crateFfiFfiRssListSources()).thenAnswer(
        (_) async => fixtureRssSourceDtoList(jsonEncode([current.toJson()])),
      );
      when(
        () => bridge.crateFfiFfiRssUpdateSource(source: any(named: 'source')),
      ).thenAnswer(
        (invocation) async =>
            invocation.namedArguments[#source] as RssSourceDto,
      );

      if (enabled) {
        await sources.enableRssSource(source.sourceUrl);
      } else {
        await sources.disableRssSource(source.sourceUrl);
      }

      final payload =
          verify(
                () => bridge.crateFfiFfiRssUpdateSource(
                  source: captureAny(named: 'source'),
                ),
              ).captured.single
              as RssSourceDto;
      expect(rssSourceFromDto(payload), current.copyWith(enabled: enabled));
      verify(() => bridge.crateFfiFfiRssListSources()).called(1);
      // 任何书源表调用或额外写入都会令此断言失败。
      verifyNoMoreInteractions(bridge);
    });
  }

  test('启停源不存在时失败且不写入', () async {
    when(() => bridge.crateFfiFfiRssListSources())
        .thenAnswer((_) async => fixtureRssSourceDtoList('[]'));
    await expectLater(sources.disableRssSource('missing'), throwsStateError);
    verify(() => bridge.crateFfiFfiRssListSources()).called(1);
    verifyNoMoreInteractions(bridge);
  });

  test('新增读取真实返回值，删除透传URL', () async {
    final saved = source.copyWith(lastUpdateTime: 100);
    when(
      () => bridge.crateFfiFfiRssAddSource(source: any(named: 'source')),
    ).thenAnswer((_) async => fixtureRssSourceDto(jsonEncode(saved.toJson())));
    when(() => bridge.crateFfiFfiRssDeleteSource(sourceUrl: source.sourceUrl))
        .thenAnswer((_) async {});
    expect(await sources.addRssSource(source), saved);
    final payload =
        verify(
              () => bridge.crateFfiFfiRssAddSource(
                source: captureAny(named: 'source'),
              ),
            ).captured.single
            as RssSourceDto;
    expect(rssSourceFromDto(payload), source);
    await sources.deleteRssSource(source.sourceUrl);
    verify(() => bridge.crateFfiFfiRssDeleteSource(sourceUrl: source.sourceUrl))
        .called(1);
    verifyNoMoreInteractions(bridge);
  });

  test('导入沿用逐条RSS写入和非对象条目跳过，导出保持完整字段', () async {
    when(() => bridge.crateFfiFfiRssAddSource(source: any(named: 'source')))
        .thenAnswer(
          (invocation) async =>
              invocation.namedArguments[#source] as RssSourceDto,
        );
    expect(await sources.importRssSources(jsonEncode([source.toJson(), 3])), 1);
    verify(() => bridge.crateFfiFfiRssAddSource(source: any(named: 'source')))
        .called(1);
    await expectLater(sources.importRssSources('{}'), throwsFormatException);
    when(() => bridge.crateFfiFfiRssListSources()).thenAnswer(
      (_) async => fixtureRssSourceDtoList(jsonEncode([source.toJson()])),
    );
    expect(jsonDecode(await sources.exportRssSources()), [source.toJson()]);
  });

  test('文章保留标题链接图片日期摘要，清理透传来源', () async {
    when(() => bridge.crateFfiFfiRssFetchArticles(sourceUrl: 'feed'))
        .thenAnswer(
          (_) async => [
            const RssArticleDto(
              title: '一',
              link: 'a',
              description: '摘要',
              pubDate: '日期',
              imageUrl: 'i',
            ),
          ],
        );
    final result = await articles.getRssArticles('feed');
    expect(result.single.url, 'a');
    expect(result.single.imageUrl, 'i');
    expect(result.single.pubDate, '日期');
    expect(result.single.description, '摘要');
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
        .thenAnswer((_) async => fixtureRssReadRecordDtoList(raw));
    when(
      () => bridge.crateFfiFfiRssListReadRecordsByOrigin(
        origin: 'feed',
        limit: 1,
      ),
    ).thenAnswer((_) async => fixtureRssReadRecordDtoList(raw));
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
    when(() => bridge.crateFfiFfiRssStarList()).thenAnswer(
      (_) async => fixtureRssStarSnapshotDtoList(jsonEncode([star.toJson()])),
    );
    expect(await stars.addRssStar(star), star);
    expect(await stars.isStarred('article'), isTrue);
    expect(await stars.getRssStars(), [star]);
    await stars.deleteRssStar('article');
    verify(() => bridge.crateFfiFfiRssStarDelete(link: 'article')).called(1);
  });

  test('合法空列表成功，FRB异常原样传播', () async {
    when(() => bridge.crateFfiFfiRssListSources())
        .thenAnswer((_) async => fixtureRssSourceDtoList('[]'));
    expect(await sources.getRssSources(), isEmpty);
    final failure = StateError('数据库失败');
    when(() => bridge.crateFfiFfiRssListSources()).thenThrow(failure);
    await expectLater(sources.getRssSources(), throwsA(same(failure)));
  });
}
