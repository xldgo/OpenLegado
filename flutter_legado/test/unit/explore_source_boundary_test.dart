import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_legado/src/app/bootstrap/book_api_bootstrap.dart';
import 'package:flutter_legado/src/services/mock_book_api.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/providers/providers.dart';
import 'package:flutter_legado/src/providers/explore/explore_dependencies.dart';

import '../mocks/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('发现状态同实例共享、按源隔离、默认值不覆盖选择，快照不泄露内存', () async {
    final api = MockBookApi();
    final container = ProviderContainer(
      overrides: [bookApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    final state = container.read(exploreStateRepositoryProvider);
    expect(state, same(api.exploreStateRepository));
    await state.ensureDefault('a', '类型', '男');
    await state.put('a', '类型', '女');
    await state.ensureDefault('a', '类型', '男');
    await state.ensureDefault('b', '类型', '男');
    expect(await api.exploreStateRepository.snapshot('a'), {'类型': '女'});
    expect(await state.snapshot('b'), {'类型': '男'});
    (await state.snapshot('a')).clear();
    expect(await state.snapshot('a'), {'类型': '女'});
  });

  test('四项能力可独立注入，不触碰根接口', () {
    final explore = ExploreServiceMock();
    final state = ExploreStateRepositoryMock();
    final query = BookSourceQueryServiceMock();
    final debug = BookSourceDebugServiceMock();
    final container = ProviderContainer(
      overrides: [
        bookApiProvider.overrideWith((_) => throw StateError('不读取根接口')),
        exploreServiceProvider.overrideWithValue(explore),
        exploreStateRepositoryProvider.overrideWithValue(state),
        bookSourceQueryServiceProvider.overrideWithValue(query),
        bookSourceDebugServiceProvider.overrideWithValue(debug),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(exploreServiceProvider), same(explore));
    expect(container.read(exploreStateRepositoryProvider), same(state));
    expect(container.read(bookSourceQueryServiceProvider), same(query));
    expect(container.read(bookSourceDebugServiceProvider), same(debug));
  });

  test('正式装配不加载原生库，四项能力保持同一实例', () {
    final api = createBookApi(useMock: false);
    final container = ProviderContainer(
      overrides: [bookApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    expect(container.read(exploreServiceProvider), same(api.exploreService));
    expect(
      container.read(exploreStateRepositoryProvider),
      same(api.exploreStateRepository),
    );
    expect(
      container.read(bookSourceQueryServiceProvider),
      same(api.bookSourceQueryService),
    );
    expect(
      container.read(bookSourceDebugServiceProvider),
      same(api.bookSourceDebugService),
    );
  });

  test('Mock保留分类、分页和调试样例，查询不会加入书架', () async {
    final api = MockBookApi();
    const source = BookSource(bookSourceUrl: 's', bookSourceName: '源');
    expect(
      (await api.exploreService.parseCategories('分类::/rank')).single.url,
      '/rank',
    );
    final books = await api.exploreService.fetchBooks(source, '/rank', 2);
    expect(books, hasLength(10));
    expect(books.first.name, '发现书籍 11');
    expect(
      (await api.bookSourceQueryService.getBookInfo(source, 'page')).origin,
      's',
    );
    expect(
      await api.bookSourceQueryService.getChapters(
        source,
        'page',
        bookUrl: 'stable',
      ),
      isEmpty,
    );
    expect(await api.bookshelfRepository.getBook('page'), isNull);
    final logs = await api.bookSourceDebugService.debug('s', 'k').toList();
    expect(logs.last.state, 1000);
  });
}
