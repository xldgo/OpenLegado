import 'package:flutter_legado/src/app/bootstrap/application_dependencies.dart';

import '../fixtures/app_test_api.dart';

import 'dart:convert';

import 'package:flutter_legado/src/data/repositories/mock_rss_article_repository.dart';
import 'package:flutter_legado/src/data/repositories/mock_rss_read_record_repository.dart';
import 'package:flutter_legado/src/data/repositories/mock_rss_source_repository.dart';
import 'package:flutter_legado/src/data/repositories/mock_rss_star_repository.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/providers/rss/rss_notifier.dart';
import 'package:flutter_legado/src/providers/rss_history/rss_history_notifier.dart';
import 'package:flutter_legado/src/providers/rss_repository_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('默认源、CRUD、启停和导出由同一装配实例保存', () async {
    final api = MockBookApi();
    final sources = api.rssSourceRepository;
    expect((await sources.getRssSources()).length, 4);
    const source = RssSource(
      sourceUrl: 'custom',
      sourceName: '自定义',
      header: '保留',
    );
    await sources.addRssSource(source);
    await sources.disableRssSource('custom');
    var custom = (await api.rssSourceRepository.getRssSources()).last;
    expect(custom.enabled, isFalse);
    expect(custom.header, '保留');
    await sources.enableRssSource('custom');
    await sources.updateRssSource(source.copyWith(sourceName: '修改后'));
    custom = (await sources.getRssSources()).last;
    expect(custom.sourceName, '修改后');
    expect((jsonDecode(await sources.exportRssSources()) as List).length, 5);
    await sources.deleteRssSource('custom');
    expect((await sources.getRssSources()).length, 4);
    await expectLater(sources.updateRssSource(source), throwsStateError);
    await expectLater(sources.enableRssSource('missing'), throwsStateError);
    await expectLater(sources.disableRssSource('missing'), throwsStateError);
  });

  test('默认源同步只替换legado分组，不删除自定义源', () async {
    final sources = MockRssSourceRepository(withDefaultSources: true);
    await sources.addRssSource(
      const RssSource(sourceUrl: 'mine', sourceName: '我的'),
    );
    expect(
      await syncDefaultRssSources(
        sources,
        jsonOverride:
            '[{"sourceUrl":"new","sourceName":"默认","sourceGroup":"legado"}]',
      ),
      1,
    );
    expect((await sources.getRssSources()).map((s) => s.sourceUrl), [
      'mine',
      'new',
    ]);
  });

  test('已读记录顺序、来源查询、limit与清空共享状态', () async {
    final records = MockRssReadRecordRepository();
    await records.rssMarkRead('a', '先读', 'one');
    await records.rssMarkRead('b', '后读');
    expect(await records.rssIsRead('one'), isTrue);
    expect(await records.rssIsReadByTitle('b', '后读'), isTrue);
    expect(await records.rssReadRecordCount(), 2);
    expect((await records.rssListReadRecords(1)).single.title, '后读');
    expect(
      (await records.rssListReadRecordsByOrigin('a', 1)).single.link,
      'one',
    );
    await records.rssClearReadRecords();
    expect(await records.rssListReadRecords(), isEmpty);
    expect(await records.rssIsRead('one'), isFalse);
    expect(await records.rssReadRecordCount(), 0);
  });

  test('收藏添加、读取、判断与删除共享同一状态', () async {
    final stars = MockRssStarRepository();
    const star = RssStar(origin: 'a', title: '标题', link: 'one');
    expect(await stars.addRssStar(star), star);
    expect(await stars.getRssStars(), [star]);
    expect(await stars.isStarred('one'), isTrue);
    await stars.deleteRssStar('one');
    expect(await stars.getRssStars(), isEmpty);
    expect(await stars.isStarred('one'), isFalse);
  });

  test('各Provider使用根装配实例并跟随窄依赖替换', () async {
    final first = MockBookApi();
    final second = MockBookApi();
    final container = ProviderContainer(
      overrides: mergeTestOverrides([
        rssSourceRepositoryProvider.overrideWithValue(
          first.rssSourceRepository,
        ),
        rssArticleRepositoryProvider.overrideWithValue(
          first.rssArticleRepository,
        ),
        rssReadRecordRepositoryProvider.overrideWithValue(
          first.rssReadRecordRepository,
        ),
        rssStarRepositoryProvider.overrideWithValue(first.rssStarRepository),
      ]),
    );
    addTearDown(container.dispose);
    expect(
      container.read(rssSourceRepositoryProvider),
      same(first.rssSourceRepository),
    );
    expect(
      container.read(rssArticleRepositoryProvider),
      same(first.rssArticleRepository),
    );
    expect(
      container.read(rssReadRecordRepositoryProvider),
      same(first.rssReadRecordRepository),
    );
    expect(
      container.read(rssStarRepositoryProvider),
      same(first.rssStarRepository),
    );
    container.updateOverrides(
      mergeTestOverrides([
        rssSourceRepositoryProvider.overrideWithValue(
          second.rssSourceRepository,
        ),
        rssArticleRepositoryProvider.overrideWithValue(
          second.rssArticleRepository,
        ),
        rssReadRecordRepositoryProvider.overrideWithValue(
          second.rssReadRecordRepository,
        ),
        rssStarRepositoryProvider.overrideWithValue(second.rssStarRepository),
      ]),
    );
    await container.pump();
    expect(
      container.read(rssSourceRepositoryProvider),
      same(second.rssSourceRepository),
    );
    expect(
      container.read(rssArticleRepositoryProvider),
      same(second.rssArticleRepository),
    );
    expect(
      container.read(rssReadRecordRepositoryProvider),
      same(second.rssReadRecordRepository),
    );
    expect(
      container.read(rssStarRepositoryProvider),
      same(second.rssStarRepository),
    );
  });

  test('订阅与历史Notifier可独立注入窄仓储，不创建根BookApi', () async {
    SharedPreferences.setMockInitialValues({
      kRssSourceVersionKey: kRssSourceVersion,
    });
    final sources = MockRssSourceRepository();
    final records = MockRssReadRecordRepository();
    await records.rssMarkRead('mine', '已读', 'one');
    final container = ProviderContainer(
      overrides: [
        rssSourceRepositoryProvider.overrideWithValue(sources),
        rssArticleRepositoryProvider.overrideWithValue(
          const MockRssArticleRepository(),
        ),
        rssReadRecordRepositoryProvider.overrideWithValue(records),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(rssNotifierProvider.notifier);
    await notifier.addSource('我的源', 'mine');
    await notifier.loadSources();
    final state = container.read(rssNotifierProvider);
    expect(state.error, isNull);
    expect(state.sources.single.sourceUrl, 'mine');
    await notifier.selectSource(state.sources.single);
    expect(container.read(rssNotifierProvider).articles.length, 5);
    await container
        .read(rssHistoryNotifierProvider.notifier)
        .load(origin: 'mine', limit: 1);
    expect(
      container.read(rssHistoryNotifierProvider).records.single.title,
      '已读',
    );
    await container.read(rssHistoryNotifierProvider.notifier).clear();
    expect(container.read(rssHistoryNotifierProvider).records, isEmpty);
  });
}
