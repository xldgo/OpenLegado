import '../fixtures/app_test_api.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_legado/src/data/bridge/search_batch_decode.dart';
import 'package:flutter_legado/src/data/repositories/mock_search_history_repository.dart';
import 'package:flutter_legado/src/data/services/mock_search_service.dart';
import 'package:flutter_legado/src/domain/models/search_batch.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/features/search/search.dart';

import '../mocks/mocks.dart';

void main() {
  group('搜索批次边界', () {
    test('缺省字段与未知 hasMore 保持', () {
      final batch = decodeSearchBatch({});
      expect(batch.books, isEmpty);
      expect(batch.sourceName, '未知书源');
      expect(batch.error, isNull);
      expect(batch.finishedCount, 0);
      expect(batch.totalCount, 0);
      expect(batch.hasMore, isNull);
    });
    test('源信息、末批、错误和进度不丢失', () {
      final batch = decodeSearchBatch({
        'source_index': 2,
        'source_url': 'fixture://source',
        'source_name': '源',
        'error': '失败',
        'finished_count': 3,
        'total_count': 8,
        'is_last': true,
        'has_more': false,
      });
      expect(batch.sourceIndex, 2);
      expect(batch.sourceUrl, 'fixture://source');
      expect(batch.sourceName, '源');
      expect(batch.error, '失败');
      expect(batch.finishedCount, 3);
      expect(batch.totalCount, 8);
      expect(batch.isLast, isTrue);
      expect(batch.hasMore, isFalse);
    });
    test('书籍类型、来源集合和已读标记保留', () {
      final batch = decodeSearchBatch({
        'books': [
          {
            'name': '中文😀',
            'author': '作者',
            'bookUrl': 'fixture://book',
            'origin': 'fixture://a',
            'originName': '甲源',
            'origins': ['fixture://a', 'fixture://b'],
            'type': 32,
            'hasReadRecord': true,
          },
        ],
      });
      final result = batch.books.single;
      expect(result.book.name, '中文😀');
      expect(result.sourceName, '甲源');
      expect(result.book.bookType, 32);
      expect(result.origins, {'fixture://a', 'fixture://b'});
      expect(result.hasReadRecord, isTrue);
    });
    test('原非对象条目仍被过滤，不凭真值推断已读', () {
      final batch = decodeSearchBatch({
        'books': [
          null,
          7,
          {'name': '书', 'hasReadRecord': 'true'},
        ],
      });
      expect(batch.books, hasLength(1));
      expect(batch.books.single.hasReadRecord, isFalse);
    });
    test('坏批次不转换为空结果', () {
      expect(
        () => decodeSearchBatch({'books': 'bad'}),
        throwsA(isA<TypeError>()),
      );
      expect(
        () => decodeSearchBatch({'finished_count': '1'}),
        throwsA(isA<TypeError>()),
      );
    });
    test('批次拥有独立的只读结果列表', () {
      final books = <SearchResult>[];
      final batch = SearchBatch(books: books);
      books.add(const SearchResult(book: Book(name: '稍后追加')));
      expect(batch.books, isEmpty);
      expect(() => batch.books.add(books.single), throwsUnsupportedError);
    });
  });
  group('历史唯一存储', () {
    test('根与独立消费者共享同一历史，返回列表不回写存储', () async {
      final repository = MockSearchHistoryRepository();
      final api = MockBookApi(searchHistoryRepository: repository);
      await repository.addSearchKeyword('甲', '原 Mock 忽略书名');
      final result = await api.searchHistoryRepository.getSearchHistory();
      result.clear();
      expect((await repository.getSearchHistory()).single.word, '甲');
    });
    test('保留重复插入、置前、上限及前缀语义', () async {
      final repository = MockSearchHistoryRepository();
      await repository.addSearchKeyword('甲', '');
      await repository.addSearchKeyword('乙', '');
      await repository.addSearchKeyword('甲', '');
      expect((await repository.getSearchHistory()).map((e) => e.word), [
        '甲',
        '乙',
        '甲',
      ]);
      expect(await repository.searchHistoryByPrefix('甲', limit: 1), ['甲']);
      expect(await repository.getSearchHistory(limit: 0), isEmpty);
      expect(await repository.searchHistoryByPrefix('不存在'), isEmpty);
    });
    test('删除所有同词，清空与独立会话隔离', () async {
      final first = MockSearchHistoryRepository();
      final second = MockSearchHistoryRepository();
      await first.addSearchKeyword('甲', '');
      await first.addSearchKeyword('甲', '');
      await first.addSearchKeyword('乙', '');
      await first.deleteSearchKeyword('甲');
      expect((await first.getSearchHistory()).single.word, '乙');
      expect(await second.getSearchHistory(), isEmpty);
      await first.clearSearchHistory();
      expect(await first.getSearchHistory(), isEmpty);
    });
  });
  group('搜索执行及装配', () {
    test('Mock 普通、精确、多源返回与控制空操作保持', () async {
      const service = MockSearchService();
      expect(await service.searchBooks('词'), hasLength(5));
      final precise = await service.preciseSearch('书', '作者', sourceUrls: []);
      expect(precise.name, '书');
      expect(precise.author, '作者');
      expect(await service.searchMulti('词'), hasLength(3));
      await service.cancelSearch();
      await service.pauseSearch();
      await service.resumeSearch();
    });
    test('Mock 流逐源输出与下一页标记保持', () async {
      final batches = await const MockSearchService()
          .searchMultiStream('词', page: 2)
          .toList();
      expect(batches, hasLength(3));
      expect(batches.map((b) => b.finishedCount), [1, 2, 3]);
      expect(
        batches.every((b) => b.books.length == 2 && b.hasMore == true),
        isTrue,
      );
      expect(batches.last.isLast, isTrue);
      expect(batches.first.books.first.book.bookType, 32);
    });
    test('两个 Provider 分享根引用且跟随根替换，不初始化', () {
      final first = MockRustApi();
      final second = MockRustApi();
      final container = ProviderContainer(
        overrides: mergeTestOverrides([
          searchServiceProvider.overrideWithValue(first.searchService),
          searchHistoryRepositoryProvider.overrideWithValue(
            first.searchHistoryRepository,
          ),
        ]),
      );
      addTearDown(container.dispose);
      expect(container.read(searchServiceProvider), same(first.searchService));
      expect(
        container.read(searchHistoryRepositoryProvider),
        same(first.searchHistoryRepository),
      );
      container.updateOverrides(
        mergeTestOverrides([
          searchServiceProvider.overrideWithValue(second.searchService),
          searchHistoryRepositoryProvider.overrideWithValue(
            second.searchHistoryRepository,
          ),
        ]),
      );
      expect(container.read(searchServiceProvider), same(second.searchService));
      expect(
        container.read(searchHistoryRepositoryProvider),
        same(second.searchHistoryRepository),
      );
      verifyNever(() => first.runtime.initialize());
      verifyNever(() => second.runtime.initialize());
    });
    test('只注入窄能力即可搜索，跨页参数与未知 hasMore 保持', () async {
      final service = SearchServiceMock();
      final repository = MockSearchHistoryRepository();
      final pages = <int>[];
      when(() => service.cancelSearch()).thenAnswer((_) async {});
      when(
        () => service.searchMultiStream(
          any(),
          sourceUrls: any(named: 'sourceUrls'),
          page: any(named: 'page'),
        ),
      ).thenAnswer((invocation) {
        pages.add(invocation.namedArguments[#page] as int);
        return Stream.value(
          SearchBatch(
            books: [
              const SearchResult(
                book: Book(name: '书', author: '作者', origin: 'fixture://源'),
              ),
            ],
            finishedCount: 1,
            totalCount: 1,
            isLast: true,
          ),
        );
      });
      final api = MockRustApi();
      when(() => api.configRepository.getConfig(any()))
          .thenAnswer((_) async => null);
      final container = ProviderContainer(
        overrides: mergeTestOverrides([
          ...api.overrides,
          searchServiceProvider.overrideWithValue(service),
          searchHistoryRepositoryProvider.overrideWithValue(repository),
        ]),
      );
      addTearDown(container.dispose);
      final notifier = container.read(searchNotifierProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      await notifier.search('词');
      await Future<void>.delayed(Duration.zero);
      expect(container.read(searchNotifierProvider).results, hasLength(1));
      expect(container.read(searchNotifierProvider).hasMore, isTrue);
      await notifier.loadNextPage();
      await Future<void>.delayed(Duration.zero);
      expect(pages, [1, 2]);
      expect(container.read(searchNotifierProvider).results, hasLength(1));
      expect((await repository.getSearchHistory()).single.word, '词');
      verifyNever(() => api.runtime.initialize());
      verifyNever(
        () => api.searchService.searchMultiStream(
          any(),
          sourceUrls: any(named: 'sourceUrls'),
          page: any(named: 'page'),
        ),
      );
    });
  });
}
