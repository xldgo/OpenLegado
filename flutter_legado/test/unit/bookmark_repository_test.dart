import 'package:flutter_legado/src/data/bridge/mock_app_runtime.dart';
import 'package:flutter_legado/src/data/repositories/mock_bookmark_repository.dart';
import 'package:flutter_legado/src/data/repositories/rust_bookmark_repository.dart';
import 'package:flutter_legado/src/app/bootstrap/book_api_bootstrap.dart';
import 'package:flutter_legado/src/domain/contracts/bookmark_repository.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/features/bookmarks/bookmarks.dart';
import 'package:flutter_legado/src/providers/providers.dart';
import 'package:flutter_legado/src/services/mock_book_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 检查直接适配、共享实例及失败完整性，不依赖旧 BookApi 书签方法。— Codex + UI
void main() {
  late _Api api;
  late BookmarkRepository repository;

  setUp(() {
    api = _Api();
    repository = api.bookmarkRepository;
  });

  test('工厂只装配正式或 Mock Repository，不访问或初始化原生库', () {
    final native = createBookApi(useMock: false);
    final mock = createBookApi(useMock: true);
    expect(native.bookmarkRepository, isA<RustBookmarkRepository>());
    expect(mock.bookmarkRepository, isA<MockBookmarkRepository>());
    expect(native.bookmarkRepository, same(native.bookmarkRepository));
    expect(mock.bookmarkRepository, same(mock.bookmarkRepository));
  });

  test('查询列表修改不污染存储，独立会话不共享书签', () async {
    final added = await repository.addBookmark(
      const Bookmark(bookName: '隔离测试', bookAuthor: '作者', content: '原备注'),
    );
    (await repository.getAllBookmarks()).clear();
    (await repository.getBookmarksByBook('隔离测试', '作者')).clear();
    (await repository.searchBookmarks('原备注')).clear();
    expect(await repository.getAllBookmarks(), [added]);
    expect(await MockBookApi().bookmarkRepository.getAllBookmarks(), isEmpty);
  });

  test('只有新增分配 ID，更新和删除保持原分配策略', () async {
    var nextId = 41;
    final store = MockBookmarkRepository(nextId: () => nextId++);
    final first = await store.addBookmark(const Bookmark(time: 123));
    await store.updateBookmark(first.copyWith(time: 0, content: '更新'));
    final second = await store.addBookmark(const Bookmark());
    expect([first.id, second.id], [41, 42]);
    expect((await store.getAllBookmarks()).first.time, 123);
    await store.deleteBookmark(first.id);
    expect(nextId, 43);
    expect(await store.getAllBookmarks(), [second]);
  });

  test('按书名与作者隔离同名书，搜索与全部查询沿用原结果', () async {
    final first = await repository.addBookmark(
      const Bookmark(bookName: '同名书', bookAuthor: '甲', bookText: '目标正文'),
    );
    final second = await api.bookmarkRepository.addBookmark(
      const Bookmark(bookName: '同名书', bookAuthor: '乙', content: '其他备注'),
    );

    expect(await repository.getBookmarksByBook('同名书', '甲'), [first]);
    expect(await repository.getBookmarksByBook('同名书', '乙'), [second]);
    expect(await repository.getBookmarksByBook('同名书', '丙'), isEmpty);
    expect(
      await repository.getAllBookmarks(),
      await api.bookmarkRepository.getAllBookmarks(),
    );
    expect(await repository.searchBookmarks('目标'), [first]);
    expect(await repository.searchBookmarks('其他'), [second]);
    expect(await repository.searchBookmarks('无命中'), isEmpty);
    expect(api.initializeCalls, 0);
  });

  test('重复更新保留 id 与创建时间，另一个消费者立即看到相同存储', () async {
    final added = await repository.addBookmark(
      const Bookmark(bookName: '测试', time: 12345, content: '原备注'),
    );
    final other = await api.bookmarkRepository.addBookmark(
      const Bookmark(content: '另一条'),
    );
    await repository.updateBookmark(added.copyWith(time: 0, content: '新备注'));
    await repository.updateBookmark(added.copyWith(time: 999, content: '再次更新'));
    final expected = added.copyWith(content: '再次更新');

    expect(await repository.getAllBookmarks(), [expected, other]);
    expect(await api.bookmarkRepository.getAllBookmarks(), [expected, other]);
    await api.bookmarkRepository.updateBookmark(
      added.copyWith(content: '外部更新'),
    );
    expect(await repository.getAllBookmarks(), [
      added.copyWith(content: '外部更新'),
      other,
    ]);
    await repository.deleteBookmark(added.id);
    expect(await api.bookmarkRepository.getAllBookmarks(), [other]);
    expect(api.initializeCalls, 0);
  });

  test('更新不存在目标时传播异常，原记录完整保留', () async {
    await repository.addBookmark(const Bookmark(time: 123, content: '保留'));
    final before = await api.bookmarkRepository.getAllBookmarks();
    await expectLater(
      repository.updateBookmark(const Bookmark(id: -1, content: '不存在')),
      throwsStateError,
    );
    expect(await repository.getAllBookmarks(), before);
  });

  test('查询和写入失败原样传递，不改为成功或触发回退', () async {
    final failure = StateError('底层失败');
    final failing = _FailingRepository()..failure = failure;
    api = _Api(bookmarks: failing);
    repository = api.bookmarkRepository;
    await expectLater(
      repository.getBookmarksByBook('书', '作者'),
      throwsA(same(failure)),
    );
    await expectLater(repository.deleteBookmark(42), throwsA(same(failure)));
    expect(api.initializeCalls, 0);
  });

  test('多个消费者共享根实例，替换 BookApi 后适配器跟随替换', () async {
    final container = ProviderContainer(
      overrides: [bookApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    final firstConsumer = Provider(
      (ref) => ref.watch(bookmarkRepositoryProvider),
    );
    final secondConsumer = Provider(
      (ref) => ref.watch(bookmarkRepositoryProvider),
    );
    final first = container.read(firstConsumer);
    expect(first, same(api.bookmarkRepository));
    expect(container.read(secondConsumer), same(first));
    final added = await first.addBookmark(const Bookmark(content: '旧存储'));
    expect(await api.bookmarkRepository.getAllBookmarks(), [added]);

    final replacement = _Api();
    final next = await replacement.bookmarkRepository.addBookmark(
      const Bookmark(content: '新存储'),
    );
    container.updateOverrides([bookApiProvider.overrideWithValue(replacement)]);
    final refreshed = container.read(firstConsumer);
    expect(refreshed, isNot(same(first)));
    expect(container.read(secondConsumer), same(refreshed));
    expect(await refreshed.getAllBookmarks(), [next]);
    expect(await api.bookmarkRepository.getAllBookmarks(), [added]);
    expect(api.initializeCalls, 0);
    expect(replacement.initializeCalls, 0);
  });
}

class _Api extends MockBookApi {
  _Api({BookmarkRepository? bookmarks}) : super(bookmarkRepository: bookmarks);

  int initializeCalls = 0;

  @override
  MockAppRuntime get runtime => _fixtureRuntime;
  late final _fixtureRuntime = MockAppRuntime(startup: _fixtureInitialize);

  Future<void> _fixtureInitialize() async => initializeCalls++;
}

class _FailingRepository extends MockBookmarkRepository {
  Object? failure;

  @override
  Future<List<Bookmark>> getBookmarksByBook(String bookName, String author) {
    final error = failure;
    if (error != null) return Future.error(error);
    return super.getBookmarksByBook(bookName, author);
  }

  @override
  Future<void> deleteBookmark(int id) {
    final error = failure;
    if (error != null) return Future.error(error);
    return super.deleteBookmark(id);
  }
}
