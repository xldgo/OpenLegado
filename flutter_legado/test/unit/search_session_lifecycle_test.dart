import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_legado/src/domain/models/search_batch.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/providers/providers.dart';
import 'package:flutter_legado/src/features/search/search.dart';

import '../mocks/mocks.dart';

Future<void> pump() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void prepare(MockRustApi api) {
  when(() => api.configRepository.getConfig(any()))
      .thenAnswer((_) async => null);
  when(
    () => api.searchHistoryRepository.getSearchHistory(
      limit: any(named: 'limit'),
    ),
  ).thenAnswer((_) async => []);
  when(() => api.searchHistoryRepository.addSearchKeyword(any(), any()))
      .thenAnswer((_) async {});
  when(() => api.searchService.cancelSearch()).thenAnswer((_) async {});
  when(() => api.searchService.pauseSearch()).thenAnswer((_) async {});
  when(() => api.searchService.resumeSearch()).thenAnswer((_) async {});
  when(
    () => api.searchService.searchMultiStream(
      any(),
      sourceUrls: any(named: 'sourceUrls'),
      page: any(named: 'page'),
    ),
  ).thenAnswer((_) => const Stream<SearchBatch>.empty());
}

void main() {
  test('根替换后暂停、恢复和停止仍控制启动实例', () async {
    final first = MockRustApi();
    final second = MockRustApi();
    prepare(first);
    prepare(second);
    final events = StreamController<SearchBatch>();
    when(
      () => first.searchService.searchMultiStream(
        any(),
        sourceUrls: any(named: 'sourceUrls'),
        page: any(named: 'page'),
      ),
    ).thenAnswer((_) => events.stream);
    final container = ProviderContainer(
      overrides: [bookApiProvider.overrideWithValue(first)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(searchNotifierProvider.notifier);
    await pump();
    await notifier.search('甲');
    container.updateOverrides([bookApiProvider.overrideWithValue(second)]);
    await notifier.pauseSearch();
    expect(container.read(searchNotifierProvider).isPaused, isTrue);
    await notifier.resumeSearch();
    await notifier.stop();
    verify(() => first.searchService.pauseSearch()).called(1);
    verify(() => first.searchService.resumeSearch()).called(1);
    verifyNever(() => second.searchService.pauseSearch());
    verifyNever(() => second.searchService.resumeSearch());
    verifyNever(() => second.searchService.cancelSearch());
    await events.close();
  });

  test('旧停止迟到完成不覆盖新搜索', () async {
    final api = MockRustApi();
    prepare(api);
    final streams = <String, StreamController<SearchBatch>>{};
    when(
      () => api.searchService.searchMultiStream(
        any(),
        sourceUrls: any(named: 'sourceUrls'),
        page: any(named: 'page'),
      ),
    ).thenAnswer(
      (call) =>
          (streams[call.positionalArguments.first as String] =
                  StreamController<SearchBatch>())
              .stream,
    );
    final container = ProviderContainer(
      overrides: [bookApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(searchNotifierProvider.notifier);
    await pump();
    await notifier.search('甲');
    final cancel = Completer<void>();
    when(() => api.searchService.cancelSearch())
        .thenAnswer((_) => cancel.future);
    final stop = notifier.stop();
    final next = notifier.search('乙');
    cancel.complete();
    await Future.wait([stop, next]);
    expect(container.read(searchNotifierProvider).keyword, '乙');
    expect(container.read(searchNotifierProvider).isManualStop, isFalse);
    expect(container.read(searchNotifierProvider).isLoading, isTrue);
    for (final controller in streams.values) {
      await controller.close();
    }
  });

  test('旧暂停迟到完成不把新搜索写为暂停', () async {
    final api = MockRustApi();
    prepare(api);
    final streams = <StreamController<SearchBatch>>[];
    when(
      () => api.searchService.searchMultiStream(
        any(),
        sourceUrls: any(named: 'sourceUrls'),
        page: any(named: 'page'),
      ),
    ).thenAnswer((_) {
      final c = StreamController<SearchBatch>();
      streams.add(c);
      return c.stream;
    });
    final container = ProviderContainer(
      overrides: [bookApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(searchNotifierProvider.notifier);
    await pump();
    await notifier.search('甲');
    final pause = Completer<void>();
    when(() => api.searchService.pauseSearch()).thenAnswer((_) => pause.future);
    final pausing = notifier.pauseSearch();
    await pump();
    final next = notifier.search('乙');
    pause.complete();
    await Future.wait([pausing, next]);
    expect(container.read(searchNotifierProvider).isPaused, isFalse);
    for (final c in streams) {
      await c.close();
    }
  });

  test('Provider 销毁取消原生并解绑当前订阅', () async {
    final api = MockRustApi();
    prepare(api);
    final events = StreamController<SearchBatch>();
    var detached = false;
    events.onCancel = () {
      detached = true;
    };
    when(
      () => api.searchService.searchMultiStream(
        any(),
        sourceUrls: any(named: 'sourceUrls'),
        page: any(named: 'page'),
      ),
    ).thenAnswer((_) => events.stream);
    final container = ProviderContainer(
      overrides: [bookApiProvider.overrideWithValue(api)],
    );
    final notifier = container.read(searchNotifierProvider.notifier);
    await pump();
    await notifier.search('甲');
    events.add(
      SearchBatch(
        books: [const SearchResult(book: Book(name: '待刷新'))],
      ),
    );
    await pump();
    clearInteractions(api.searchService);
    container.dispose();
    await pump();
    await Future<void>.delayed(const Duration(milliseconds: 170));
    expect(detached, isTrue);
    verify(() => api.searchService.cancelSearch()).called(1);
    await events.close();
  });
  test('旧取消阻塞时连续提交只启动最后关键词，并等待解绑', () async {
    final api = MockRustApi();
    prepare(api);
    final started = <String>[];
    final old = StreamController<SearchBatch>();
    final detached = Completer<void>();
    old.onCancel = () => detached.future;
    final newest = StreamController<SearchBatch>();
    when(
      () => api.searchService.searchMultiStream(
        any(),
        sourceUrls: any(named: 'sourceUrls'),
        page: any(named: 'page'),
      ),
    ).thenAnswer((call) {
      final key = call.positionalArguments.first as String;
      started.add(key);
      return key == '原查询' ? old.stream : newest.stream;
    });
    final container = ProviderContainer(
      overrides: [bookApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(searchNotifierProvider.notifier);
    await pump();
    await notifier.search('原查询');
    final cancel = Completer<void>();
    when(() => api.searchService.cancelSearch())
        .thenAnswer((_) => cancel.future);
    final first = notifier.search('较早');
    final second = notifier.search('最新');
    await pump();
    expect(started, ['原查询']);
    expect(container.read(searchNotifierProvider).keyword, '最新');
    cancel.complete();
    await pump();
    expect(started, ['原查询'], reason: '原生取消完成但解绑尚未完成');
    detached.complete();
    await Future.wait([first, second]);
    expect(started, ['原查询', '最新']);
    await notifier.stop();
    await old.close();
    await newest.close();
  });

  test('历史准备期间停止不启动原生搜索，也不发送无主取消', () async {
    final api = MockRustApi();
    prepare(api);
    final history = Completer<void>();
    when(() => api.searchHistoryRepository.addSearchKeyword(any(), any()))
        .thenAnswer((_) => history.future);
    final container = ProviderContainer(
      overrides: [bookApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(searchNotifierProvider.notifier);
    await pump();
    final start = notifier.search('准备中');
    await pump();
    await notifier.stop();
    history.complete();
    await start;
    expect(container.read(searchNotifierProvider).isManualStop, isTrue);
    verifyNever(() => api.searchService.cancelSearch());
    verifyNever(
      () => api.searchService.searchMultiStream(
        any(),
        sourceUrls: any(named: 'sourceUrls'),
        page: any(named: 'page'),
      ),
    );
  });

  test('准备期间根替换仍绑定发起时实例', () async {
    final first = MockRustApi();
    final second = MockRustApi();
    prepare(first);
    prepare(second);
    final history = Completer<void>();
    when(() => first.searchHistoryRepository.addSearchKeyword(any(), any()))
        .thenAnswer((_) => history.future);
    final container = ProviderContainer(
      overrides: [bookApiProvider.overrideWithValue(first)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(searchNotifierProvider.notifier);
    await pump();
    final start = notifier.search('甲');
    await pump();
    container.updateOverrides([bookApiProvider.overrideWithValue(second)]);
    history.complete();
    await start;
    await pump();
    verify(
      () =>
          first.searchService.searchMultiStream('甲', sourceUrls: null, page: 1),
    ).called(1);
    verifyNever(
      () => second.searchService.searchMultiStream(
        any(),
        sourceUrls: any(named: 'sourceUrls'),
        page: any(named: 'page'),
      ),
    );
  });

  test('自然完成后续页仍绑定原实例，不重复取消', () async {
    final first = MockRustApi();
    final second = MockRustApi();
    prepare(first);
    prepare(second);
    final pages = <int>[];
    when(
      () => first.searchService.searchMultiStream(
        any(),
        sourceUrls: any(named: 'sourceUrls'),
        page: any(named: 'page'),
      ),
    ).thenAnswer((call) {
      pages.add(call.namedArguments[#page] as int);
      return Stream.value(SearchBatch(hasMore: true));
    });
    final container = ProviderContainer(
      overrides: [bookApiProvider.overrideWithValue(first)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(searchNotifierProvider.notifier);
    await pump();
    await notifier.search('甲');
    await pump();
    container.updateOverrides([bookApiProvider.overrideWithValue(second)]);
    await notifier.loadNextPage();
    await pump();
    expect(pages, [1, 2]);
    verifyNever(() => first.searchService.cancelSearch());
    verifyNever(
      () => second.searchService.searchMultiStream(
        any(),
        sourceUrls: any(named: 'sourceUrls'),
        page: any(named: 'page'),
      ),
    );
  });

  test('在途暂停后立即恢复会顺序执行，旧控制不回写', () async {
    final api = MockRustApi();
    prepare(api);
    final events = StreamController<SearchBatch>();
    when(
      () => api.searchService.searchMultiStream(
        any(),
        sourceUrls: any(named: 'sourceUrls'),
        page: any(named: 'page'),
      ),
    ).thenAnswer((_) => events.stream);
    final container = ProviderContainer(
      overrides: [bookApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(searchNotifierProvider.notifier);
    await pump();
    await notifier.search('甲');
    final pause = Completer<void>();
    final calls = <String>[];
    when(() => api.searchService.pauseSearch()).thenAnswer((_) {
      calls.add('暂停');
      return pause.future;
    });
    when(() => api.searchService.resumeSearch()).thenAnswer((_) async {
      calls.add('恢复');
    });
    final pausing = notifier.pauseSearch();
    await pump();
    final resuming = notifier.resumeSearch();
    expect(calls, ['暂停']);
    pause.complete();
    await Future.wait([pausing, resuming]);
    expect(calls, ['暂停', '恢复']);
    expect(container.read(searchNotifierProvider).isPaused, isFalse);
    await notifier.stop();
    await events.close();
  });

  test('暂停恢复失败不回写并允许重试，重复暂停只发一次', () async {
    final api = MockRustApi();
    prepare(api);
    final events = StreamController<SearchBatch>();
    when(
      () => api.searchService.searchMultiStream(
        any(),
        sourceUrls: any(named: 'sourceUrls'),
        page: any(named: 'page'),
      ),
    ).thenAnswer((_) => events.stream);
    final container = ProviderContainer(
      overrides: [bookApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(searchNotifierProvider.notifier);
    await pump();
    await notifier.search('甲');
    when(() => api.searchService.pauseSearch()).thenThrow(StateError('暂停失败'));
    await notifier.pauseSearch();
    expect(container.read(searchNotifierProvider).isPaused, isFalse);
    final pause = Completer<void>();
    when(() => api.searchService.pauseSearch()).thenAnswer((_) => pause.future);
    clearInteractions(api.searchService);
    final first = notifier.pauseSearch();
    final duplicate = notifier.pauseSearch();
    await pump();
    verify(() => api.searchService.pauseSearch()).called(1);
    pause.complete();
    await Future.wait([first, duplicate]);
    expect(container.read(searchNotifierProvider).isPaused, isTrue);
    when(() => api.searchService.resumeSearch()).thenThrow(StateError('恢复失败'));
    await notifier.resumeSearch();
    expect(container.read(searchNotifierProvider).isPaused, isTrue);
    when(() => api.searchService.resumeSearch()).thenAnswer((_) async {});
    await notifier.resumeSearch();
    expect(container.read(searchNotifierProvider).isPaused, isFalse);
    await notifier.stop();
    await events.close();
  });

  for (final reset in [false, true]) {
    test('${reset ? "重开" : "清空"}立即隔离旧批次、错误和完成', () async {
      final api = MockRustApi();
      prepare(api);
      final events = StreamController<SearchBatch>();
      when(
        () => api.searchService.searchMultiStream(
          any(),
          sourceUrls: any(named: 'sourceUrls'),
          page: any(named: 'page'),
        ),
      ).thenAnswer((_) => events.stream);
      final container = ProviderContainer(
        overrides: [bookApiProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(searchNotifierProvider.notifier);
      await pump();
      await notifier.search('甲');
      final cancel = Completer<void>();
      when(() => api.searchService.cancelSearch())
          .thenAnswer((_) => cancel.future);
      events.add(
        SearchBatch(
          books: [const SearchResult(book: Book(name: '旧结果'))],
          finishedCount: 1,
        ),
      );
      await pump();
      reset ? notifier.resetForOpen() : notifier.clearResults();
      events.add(
        SearchBatch(
          books: [const SearchResult(book: Book(name: '迟到结果'))],
        ),
      );
      events.addError(StateError('迟到错误'));
      await pump();
      await Future<void>.delayed(const Duration(milliseconds: 170));
      expect(container.read(searchNotifierProvider).results, isEmpty);
      expect(container.read(searchNotifierProvider).searchedCount, 0);
      expect(container.read(searchNotifierProvider).error, isNull);
      cancel.complete();
      await events.close();
      expect(container.read(searchNotifierProvider).keyword, '');
    });
  }

  test('旧页面延迟停止不影响同步启动的新查询', () async {
    final api = MockRustApi();
    prepare(api);
    final streams = <StreamController<SearchBatch>>[];
    when(
      () => api.searchService.searchMultiStream(
        any(),
        sourceUrls: any(named: 'sourceUrls'),
        page: any(named: 'page'),
      ),
    ).thenAnswer((_) {
      final events = StreamController<SearchBatch>();
      streams.add(events);
      return events.stream;
    });
    final container = ProviderContainer(
      overrides: [bookApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(searchNotifierProvider.notifier);
    await pump();
    await notifier.search('旧');
    notifier.stopOnPageExit();
    final next = notifier.search('新');
    await next;
    await pump();
    expect(container.read(searchNotifierProvider).keyword, '新');
    expect(container.read(searchNotifierProvider).isManualStop, isFalse);
    expect(container.read(searchNotifierProvider).isLoading, isTrue);
    expect(container.read(searchNotifierProvider).error, isNull);
    await notifier.stop();
    for (final events in streams) {
      await events.close();
    }
  });

  test('流异常保留已出结果并清理，取消失败仍解绑且可继续搜索', () async {
    final api = MockRustApi();
    prepare(api);
    final events = StreamController<SearchBatch>();
    var detached = false;
    events.onCancel = () {
      detached = true;
    };
    var starts = 0;
    when(
      () => api.searchService.searchMultiStream(
        any(),
        sourceUrls: any(named: 'sourceUrls'),
        page: any(named: 'page'),
      ),
    ).thenAnswer(
      (_) => starts++ == 0 ? events.stream : const Stream<SearchBatch>.empty(),
    );
    final container = ProviderContainer(
      overrides: [bookApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(searchNotifierProvider.notifier);
    await pump();
    await notifier.search('甲');
    when(() => api.searchService.cancelSearch()).thenThrow(StateError('取消失败'));
    events.add(
      SearchBatch(
        books: [const SearchResult(book: Book(name: '保留'))],
      ),
    );
    await pump();
    events.addError(StateError('流失败'));
    await pump();
    expect(
      container.read(searchNotifierProvider).results.single.book.name,
      '保留',
    );
    expect(container.read(searchNotifierProvider).error, contains('流失败'));
    expect(detached, isTrue);
    await notifier.search('乙');
    await pump();
    expect(container.read(searchNotifierProvider).isLoading, isFalse);
    expect(container.read(searchNotifierProvider).error, isNull);
    await events.close();
  });

  test('同步启动失败不留下活动会话，下一查询正常', () async {
    final api = MockRustApi();
    prepare(api);
    var starts = 0;
    when(
      () => api.searchService.searchMultiStream(
        any(),
        sourceUrls: any(named: 'sourceUrls'),
        page: any(named: 'page'),
      ),
    ).thenAnswer((_) {
      if (starts++ == 0) throw StateError('启动失败');
      return const Stream<SearchBatch>.empty();
    });
    final container = ProviderContainer(
      overrides: [bookApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(searchNotifierProvider.notifier);
    await pump();
    await notifier.search('甲');
    expect(container.read(searchNotifierProvider).error, contains('启动失败'));
    expect(container.read(searchNotifierProvider).isLoading, isFalse);
    await notifier.search('乙');
    await pump();
    expect(container.read(searchNotifierProvider).error, isNull);
    verifyNever(() => api.searchService.cancelSearch());
  });
  test('已结束页的在途暂停完成前不启动下一页', () async {
    final api = MockRustApi();
    prepare(api);
    final first = StreamController<SearchBatch>();
    final pages = <int>[];
    when(
      () => api.searchService.searchMultiStream(
        any(),
        sourceUrls: any(named: 'sourceUrls'),
        page: any(named: 'page'),
      ),
    ).thenAnswer((call) {
      final page = call.namedArguments[#page] as int;
      pages.add(page);
      return page == 1 ? first.stream : const Stream<SearchBatch>.empty();
    });
    final container = ProviderContainer(
      overrides: [bookApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(searchNotifierProvider.notifier);
    await pump();
    await notifier.search('甲');
    final pause = Completer<void>();
    when(() => api.searchService.pauseSearch()).thenAnswer((_) => pause.future);
    final pausing = notifier.pauseSearch();
    await pump();
    first.add(SearchBatch(hasMore: true));
    await first.close();
    await pump();
    final next = notifier.loadNextPage();
    await pump();
    expect(pages, [1]);
    pause.complete();
    await Future.wait([pausing, next]);
    await pump();
    expect(pages, [1, 2]);
    expect(container.read(searchNotifierProvider).isPaused, isFalse);
  });

  test('销毁过滤准备中的迟到历史，不再启动搜索或访问 Provider', () async {
    final api = MockRustApi();
    prepare(api);
    final history = Completer<void>();
    when(() => api.searchHistoryRepository.addSearchKeyword(any(), any()))
        .thenAnswer((_) => history.future);
    final container = ProviderContainer(
      overrides: [bookApiProvider.overrideWithValue(api)],
    );
    final notifier = container.read(searchNotifierProvider.notifier);
    await pump();
    final start = notifier.search('准备');
    await pump();
    container.dispose();
    history.complete();
    await start;
    verifyNever(
      () => api.searchService.searchMultiStream(
        any(),
        sourceUrls: any(named: 'sourceUrls'),
        page: any(named: 'page'),
      ),
    );
    verifyNever(() => api.searchService.cancelSearch());
  });
  test('Provider 失效重建后仍可搜索，旧准备不得回填', () async {
    final api = MockRustApi();
    prepare(api);
    final history = Completer<void>();
    var writes = 0;
    when(
      () => api.searchHistoryRepository.addSearchKeyword(any(), any()),
    ).thenAnswer((_) => writes++ == 0 ? history.future : Future<void>.value());
    final container = ProviderContainer(
      overrides: [bookApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    var notifier = container.read(searchNotifierProvider.notifier);
    await pump();
    final old = notifier.search('旧');
    await pump();
    container.invalidate(searchNotifierProvider);
    notifier = container.read(searchNotifierProvider.notifier);
    await pump();
    await notifier.search('新');
    history.complete();
    await old;
    await pump();
    expect(container.read(searchNotifierProvider).keyword, '新');
    expect(container.read(searchNotifierProvider).isLoading, isFalse);
    verifyNever(
      () => api.searchService.searchMultiStream('旧', sourceUrls: null, page: 1),
    );
  });

  for (final resume in [false, true]) {
    test('准备期后台暂停${resume ? "且恢复" : ""}意图在启动时保持', () async {
      final api = MockRustApi();
      prepare(api);
      final history = Completer<void>();
      final events = StreamController<SearchBatch>();
      when(() => api.searchHistoryRepository.addSearchKeyword(any(), any()))
          .thenAnswer((_) => history.future);
      when(
        () => api.searchService.searchMultiStream(
          any(),
          sourceUrls: any(named: 'sourceUrls'),
          page: any(named: 'page'),
        ),
      ).thenAnswer((_) => events.stream);
      final container = ProviderContainer(
        overrides: [bookApiProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(searchNotifierProvider.notifier);
      await pump();
      final start = notifier.search('准备');
      await pump();
      await notifier.pauseSearch();
      if (resume) await notifier.resumeSearch();
      verifyNever(() => api.searchService.pauseSearch());
      history.complete();
      await start;
      await pump();
      expect(container.read(searchNotifierProvider).isPaused, !resume);
      if (resume) {
        verifyNever(() => api.searchService.pauseSearch());
      } else {
        verify(() => api.searchService.pauseSearch()).called(1);
      }
      await notifier.stop();
      await events.close();
    });
  }
}
