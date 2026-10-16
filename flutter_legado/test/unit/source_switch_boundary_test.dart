import 'package:flutter_legado/src/app/bootstrap/application_dependencies.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../fixtures/native_test_api.dart';

import 'package:flutter_legado/src/domain/models/cover_rule.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/providers/change_source/change_source_notifier.dart';

import '../mocks/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('三个窄Provider可独立替换，不读取根接口', () {
    final service = SourceSwitchServiceMock();
    final covers = CoverSearchServiceMock();
    final rules = CoverRuleRepositoryMock();
    final container = ProviderContainer(
      overrides: [
        sourceSwitchServiceProvider.overrideWithValue(service),
        coverSearchServiceProvider.overrideWithValue(covers),
        coverRuleRepositoryProvider.overrideWithValue(rules),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(sourceSwitchServiceProvider), same(service));
    expect(container.read(coverSearchServiceProvider), same(covers));
    expect(container.read(coverRuleRepositoryProvider), same(rules));
    final api = createTestApplication(useMock: false);
    expect(api.sourceSwitchService, same(api.sourceSwitchService));
    expect(api.coverSearchService, same(api.coverSearchService));
    expect(api.coverRuleRepository, same(api.coverRuleRepository));
  });
  test('取消使用发起换源的实例，异常清理应用状态', () async {
    final service = SourceSwitchServiceMock();
    final replacement = SourceSwitchServiceMock();
    final response = Completer<Book>();
    when(() => service.switchSourcePrefetch('stable', 's', 'page'))
        .thenAnswer((_) => response.future);
    when(() => service.cancelSwitchSourceApply()).thenAnswer((_) async {});
    final container = ProviderContainer(
      overrides: [sourceSwitchServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(changeSourceNotifierProvider.notifier);
    final pending = notifier.applySource(
      const SourceMatch(sourceUrl: 's', bookUrl: 'page'),
      bookUrl: 'stable',
    );
    final failure = expectLater(pending, throwsStateError);
    container.updateOverrides([
      sourceSwitchServiceProvider.overrideWithValue(replacement),
    ]);
    await notifier.cancelApply();
    verify(() => service.cancelSwitchSourceApply()).called(1);
    verifyZeroInteractions(replacement);
    response.completeError(StateError('已取消'));
    await failure;
    expect(container.read(changeSourceNotifierProvider).isApplying, isFalse);
  });
  test('Mock换源与书架共用记录，保留进度、配置和稳定主键', () async {
    final api = MockBookApi();
    const original = Book(
      bookUrl: 'stable',
      name: '书',
      author: '作者',
      durChapterIndex: 4,
      durChapterPos: 67,
      readConfig: ReadConfig(ttsEngine: 'system://default'),
    );
    await api.bookshelfRepository.addBook(original);
    final switched = await api.sourceSwitchService.switchSourcePrefetch(
      'stable',
      'https://www.biquge.com.cn',
      'new-page',
    );
    expect(switched.bookUrl, 'stable');
    expect(switched.originBookUrl, 'new-page');
    expect(switched.originName, '笔趣阁');
    expect(switched.durChapterIndex, 4);
    expect(switched.durChapterPos, 67);
    expect(switched.readConfig, original.readConfig);
    expect(await api.bookshelfRepository.getBook('stable'), switched);
    expect(await api.bookshelfRepository.getBook('new-page'), isNull);
    await expectLater(
      api.sourceSwitchService.switchSource('missing', 's', 'p'),
      throwsStateError,
    );
  });
  test('Mock候选评分、删除和过滤共用状态，批次为完整快照', () async {
    final service = MockBookApi().sourceSwitchService;
    final candidates = await service.searchSource('书', '作者');
    await service.updateSearchBookScore(candidates.first.bookUrl, 1);
    expect((await service.searchSource('书', '作者')).first.bookScore, 1);
    await service.deleteSearchBook(candidates.first.bookUrl);
    final filtered = await service.searchSource(
      '书',
      '作者',
      sourceUrls: [candidates.last.sourceUrl],
    );
    expect(filtered, [candidates.last]);
    final batches = await service.searchSourceStream('书', '作者').toList();
    expect(batches.map((b) => b.matches.length), [1, 2]);
    expect(batches.last.isLast, isTrue);
    expect(
      batches.last.matches.map((m) => m.bookUrl),
      candidates.skip(1).map((m) => m.bookUrl),
    );
    await expectLater(
      service.updateSearchBookScore(candidates.first.bookUrl, 1),
      throwsStateError,
    );
  });
  test('Mock封面规则读写共享同一对象并支持恢复默认', () async {
    final api = MockBookApi();
    const rule = CoverRule(
      enable: false,
      searchUrl: 'u',
      coverRule: 'r',
      enabledCookieJar: true,
    );
    expect(await api.coverRuleRepository.saveCoverRule(rule), isTrue);
    expect(await api.coverRuleRepository.getCoverRule(), same(rule));
    await api.coverRuleRepository.deleteCoverRule();
    expect(
      (await api.coverRuleRepository.getCoverRule()).searchUrl,
      contains('{{key}}'),
    );
  });
}
