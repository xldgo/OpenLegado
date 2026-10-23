import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_legado/src/app/bootstrap/application_dependencies.dart';
import 'package:flutter_legado/src/domain/contracts/search_aggregation_service.dart';
import 'package:flutter_legado/src/domain/models/search_batch.dart';
import 'package:flutter_legado/src/features/search/search.dart';
import 'package:flutter_legado/src/models/models.dart';

import '../fixtures/app_test_api.dart';
import '../mocks/mocks.dart';

class _Service implements SearchAggregationService {
  final sessions = <_Session>[];
  @override
  SearchAggregationSession open(String keyword) {
    final session = _Session();
    sessions.add(session);
    return session;
  }
}

class _Session implements SearchAggregationSession {
  final result = Completer<List<SearchResult>>();
  final received = <SearchResult>[];
  int closed = 0;
  @override
  Future<void> addAll(List<SearchResult> books) async {
    received.addAll(books);
  }

  @override
  Future<List<SearchResult>> snapshot({bool keepOther = true}) => result.future;
  @override
  Future<void> close() async {
    closed++;
  }
}

Future<void> pump() async {
  for (var i = 0; i < 12; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  setUpAll(registerFallbacks);
  late MockRustApi api;
  late ProviderContainer container;
  late _Service aggregation;
  final streams = <StreamController<SearchBatch>>[];
  SearchNotifier notifier() => container.read(searchNotifierProvider.notifier);
  SearchState state() => container.read(searchNotifierProvider);
  const book = SearchResult(
    book: Book(name: '甲', author: '作者', origin: 'a', bookUrl: 'a/book'),
  );
  setUp(() {
    api = MockRustApi();
    aggregation = _Service();
    streams.clear();
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
    when(
      () => api.searchService.searchMultiStream(
        any(),
        sourceUrls: any(named: 'sourceUrls'),
        page: any(named: 'page'),
      ),
    ).thenAnswer((_) {
      final stream = StreamController<SearchBatch>();
      streams.add(stream);
      return stream.stream;
    });
    container = ProviderContainer(
      overrides: mergeTestOverrides([
        ...api.overrides,
        searchAggregationServiceProvider.overrideWithValue(aggregation),
      ]),
    );
  });
  tearDown(() async {
    container.dispose();
    for (final stream in streams) {
      await stream.close();
    }
    await pump();
  });
  test('流结束等待最后快照，最终结果和进度一起发布', () async {
    await notifier().search('甲');
    streams.single.add(
      SearchBatch(books: [book], finishedCount: 1, totalCount: 1),
    );
    await pump();
    unawaited(streams.single.close());
    await pump();
    expect(state().isLoading, true);
    expect(state().results, isEmpty);
    expect(aggregation.sessions.single.received, [book]);
    aggregation.sessions.single.result.complete([book]);
    await pump();
    expect(state().isLoading, false);
    expect(state().results, [book]);
    expect((state().searchedCount, state().totalCount), (1, 1));
  });
  test('流错误立即隔离后续批次，等待快照时仍显示原错误', () async {
    await notifier().search('甲');
    final stream = streams.single;
    stream.add(SearchBatch(books: [book]));
    await pump();
    stream.addError(StateError('网络中断'));
    await pump();
    expect(state().error, contains('网络中断'));
    expect(state().isLoading, false);
    stream.add(
      SearchBatch(
        books: [book.copyWith(book: book.book.copyWith(name: '迟到'))],
      ),
    );
    await pump();
    expect(aggregation.sessions.single.received, [book]);
    aggregation.sessions.single.result.complete([book]);
    await pump();
    expect(state().results, [book]);
    expect(state().error, contains('网络中断'));
  });

  test('停止等待快照时可以重搜，旧快照不能覆盖新查询，清空释放新会话', () async {
    await notifier().search('旧');
    streams.single.add(
      SearchBatch(books: [book], finishedCount: 1, totalCount: 1),
    );
    await pump();
    final stopped = notifier().stop();
    await pump();
    expect(state().isManualStop, true);
    await notifier().search('新');
    final latest = book.copyWith(book: book.book.copyWith(name: '新'));
    streams.last.add(
      SearchBatch(books: [latest], finishedCount: 1, totalCount: 1),
    );
    unawaited(streams.last.close());
    await pump();
    aggregation.sessions.last.result.complete([latest]);
    await pump();
    aggregation.sessions.first.result.complete([book]);
    await stopped;
    await pump();
    expect(state().keyword, '新');
    expect(state().results, [latest]);
    expect(aggregation.sessions.first.closed, 1);
    notifier().clearResults();
    await pump();
    expect(state().results, isEmpty);
    expect(aggregation.sessions.last.closed, 1);
  });
}
