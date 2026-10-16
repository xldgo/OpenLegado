import 'package:flutter_legado/src/data/bridge/mock_app_runtime.dart';

import 'dart:async';

import 'package:flutter_legado/src/data/repositories/mock_book_group_repository.dart';
import 'package:flutter_legado/src/data/repositories/mock_bookshelf_repository.dart';
import 'package:flutter_legado/src/data/repositories/rust_bookshelf_repository.dart';
import 'package:flutter_legado/src/data/repositories/rust_book_group_repository.dart';
import 'package:flutter_legado/src/app/bootstrap/book_api_bootstrap.dart';
import 'package:flutter_legado/src/domain/contracts/book_group_repository.dart';
import 'package:flutter_legado/src/domain/contracts/bookshelf_repository.dart';
import 'package:flutter_legado/src/features/bookshelf/bookshelf.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/providers/providers.dart';
import 'package:flutter_legado/src/providers/app_settings_provider.dart';
import 'package:flutter_legado/src/data/services/app_settings_service.dart';
import 'package:flutter_legado/src/domain/models/app_settings_snapshot.dart';
import 'package:flutter_legado/src/services/mock_book_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../mocks/mocks.dart';
import '../fixtures/home_settings_storage.dart';

class _Shelf extends Mock implements BookshelfRepository {}

class _Groups extends Mock implements BookGroupRepository {}

class _Api extends MockBookApi {
  int initializeCalls = 0;
  @override
  MockAppRuntime get runtime => _fixtureRuntime;
  late final _fixtureRuntime = MockAppRuntime(startup: _fixtureInitialize);

  Future<void> _fixtureInitialize() async => initializeCalls++;
}

const _book = Book(
  bookUrl: 'book://boundary',
  name: '书架边界',
  author: '作者',
  group: 8,
  order: 3,
  durChapterIndex: 2,
  durChapterPos: 91,
);

Future<void> _flush() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    registerFallbacks();
    registerFallbackValue(const BookGroup());
    registerFallbackValue(<Map<String, dynamic>>[]);
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('工厂只装配共享正式或 Mock 引用，不初始化运行时', () {
    final native = createBookApi(useMock: false);
    final mock = _Api();
    expect(native.bookshelfRepository, isA<RustBookshelfRepository>());
    expect(native.bookGroupRepository, isA<RustBookGroupRepository>());
    expect(mock.bookshelfRepository, isA<MockBookshelfRepository>());
    expect(mock.bookGroupRepository, isA<MockBookGroupRepository>());
    expect(native.bookshelfRepository, same(native.bookshelfRepository));
    expect(mock.bookGroupRepository, same(mock.bookGroupRepository));
    expect(mock.initializeCalls, 0);
  });

  test('书架、阅读进度、章节样例与本地导入共享唯一 Mock 存储', () async {
    final api = _Api();
    final shelf = api.bookshelfRepository;
    final sample = (await shelf.getBooks()).first;
    expect(await api.readingRepository.getChapters(sample.bookUrl), isNotEmpty);
    await shelf.addBook(_book);
    (await shelf.getBooks()).clear();
    expect(await shelf.getBook(_book.bookUrl), _book);
    await api.readingRepository.updateReadingProgress(
      bookUrl: _book.bookUrl,
      chapterIndex: 3,
      chapterPos: 201,
    );
    expect((await shelf.getBook(_book.bookUrl))!.durChapterPos, 201);
    final imported = await api.localBookService.importLocalBook(
      'fixture/book.txt',
    );
    expect(await shelf.getBook(imported.bookUrl), imported);
    await shelf.updateBook(_book.copyWith(name: '更新', durChapterPos: 123));
    await shelf.setBookGroup(_book.bookUrl, -3);
    expect((await shelf.getBook(_book.bookUrl))!.group, -3);
    await shelf.topBook(_book.bookUrl);
    expect((await shelf.getBook(_book.bookUrl))!.order, -1);
    await shelf.unTopBook(_book.bookUrl);
    expect((await shelf.getBook(_book.bookUrl))!.order, 0);
    await shelf.deleteBook(_book.bookUrl);
    expect(await shelf.getBook(_book.bookUrl), isNull);
    expect(api.initializeCalls, 0);
  });

  test('Mock 保持完整分组更新、根 ID 分配、列表副本和原显隐边界', () async {
    final api = _Api();
    final groups = api.bookGroupRepository;
    expect((await groups.getBookGroups()).map((g) => g.groupName), [
      '科幻',
      '收藏',
    ]);
    final bookmark = await api.bookmarkRepository.addBookmark(const Bookmark());
    final group = await groups.addBookGroup(
      const BookGroup(groupName: '新分组', show: false),
    );
    expect(group.groupId, bookmark.id + 1);
    final next = group.copyWith(
      groupName: '更新',
      show: true,
      enableRefresh: false,
      cover: '',
      order: -5,
    );
    await groups.updateBookGroup(next);
    expect(await groups.getBookGroups(), contains(next));
    (await groups.getBookGroups()).clear();
    expect(await groups.getBookGroups(), contains(next));
    expect(await groups.bookGroupSetShow(next.groupId, false), isTrue);
    expect(await groups.getBookGroups(), contains(next));
    await api.bookshelfRepository.addBook(_book.copyWith(group: next.groupId));
    await groups.deleteBookGroup(next.groupId);
    expect(
      (await api.bookshelfRepository.getBook(_book.bookUrl))!.group,
      next.groupId,
    );
  });

  test('并发加载只调用一次，资产加载失败继续传播同一失败', () async {
    var calls = 0;
    final pending = Completer<void>();
    late MockBookshelfStore store;
    store = MockBookshelfStore(
      load: () async {
        calls++;
        await pending.future;
        store.books.add(_book);
      },
    );
    final shelf = MockBookshelfRepository(store: store);
    final list = shelf.getBooks();
    final book = shelf.getBook(_book.bookUrl);
    pending.complete();
    expect(await list, [_book]);
    expect(await book, _book);
    expect(calls, 1);
    var failedCalls = 0;
    final error = StateError('资产失败');
    final failing = MockBookshelfRepository(
      store: MockBookshelfStore(
        load: () async {
          failedCalls++;
          throw error;
        },
      ),
    );
    await expectLater(failing.getBooks(), throwsA(same(error)));
    await expectLater(failing.getBook('x'), throwsA(same(error)));
    expect(failedCalls, 1);
  });

  test('Mock 导入保留只返回数量的旧边界，排序和缺失目标保持原行为', () async {
    final shelf = MockBookshelfRepository();
    expect(await shelf.importBooks('[{"name":"不插入"}]'), 1);
    expect(await shelf.getBooks(), isEmpty);
    await expectLater(shelf.importBooks('不是JSON'), throwsFormatException);
    await shelf.updateBook(_book);
    await shelf.topBook('不存在');
    await shelf.addBook(_book);
    await shelf.addBook(_book.copyWith(bookUrl: '第二本', order: 7));
    await shelf.reorderBooks([
      {'bookUrl': _book.bookUrl, 'order': 8},
      {'bookUrl': '第二本', 'order': -1},
      {'order': 0},
    ]);
    expect((await shelf.getBooks()).map((b) => b.bookUrl), [
      '第二本',
      _book.bookUrl,
    ]);
    expect(await shelf.getBook('不存在'), isNull);
  });

  test('根替换后两个 Provider 跟随新存储，旧引用只访问旧实例', () async {
    final old = _Api();
    final next = _Api();
    final container = ProviderContainer(
      overrides: [bookApiProvider.overrideWithValue(old)],
    );
    addTearDown(container.dispose);
    final shelf = container.read(bookshelfRepositoryProvider);
    final groups = container.read(bookGroupRepositoryProvider);
    await shelf.addBook(_book);
    expect(shelf, same(old.bookshelfRepository));
    expect(groups, same(old.bookGroupRepository));
    container.updateOverrides([bookApiProvider.overrideWithValue(next)]);
    expect(
      container.read(bookshelfRepositoryProvider),
      same(next.bookshelfRepository),
    );
    expect(
      container.read(bookGroupRepositoryProvider),
      same(next.bookGroupRepository),
    );
    expect(
      await container.read(bookshelfRepositoryProvider).getBook(_book.bookUrl),
      isNull,
    );
    expect(await shelf.getBook(_book.bookUrl), _book);
  });

  group('只注入窄接口的消费者', () {
    late _Shelf shelf;
    late _Groups groups;
    late ProviderContainer container;
    setUp(() {
      shelf = _Shelf();
      groups = _Groups();
      when(() => shelf.getBooks()).thenAnswer((_) async => [_book]);
      when(() => groups.getBookGroups()).thenAnswer(
        (_) async => const [
          BookGroup(groupId: 8, groupName: '显示组', order: 2),
          BookGroup(groupId: 9, groupName: '隐藏组', show: false),
        ],
      );
      container = ProviderContainer(
        overrides: [
          bookApiProvider.overrideWith(
            (_) => throw StateError('CRUD 不应创建 BookApi'),
          ),
          appSettingsServiceProvider.overrideWith((ref) {
            final service = AppSettingsService(
              storages: {
                SettingsStorageKind.preferences: HomeSettingsStorage(),
              },
            );
            ref.onDispose(() => service.dispose());
            return service;
          }),
          bookshelfRepositoryProvider.overrideWithValue(shelf),
          bookGroupRepositoryProvider.overrideWithValue(groups),
        ],
      );
      addTearDown(container.dispose);
    });

    test('书架初始化、定向刷新、增删和分组筛选不触发巨大接口', () async {
      final notifier = container.read(bookshelfNotifierProvider.notifier);
      await _flush();
      expect(container.read(bookshelfNotifierProvider).books, [_book]);
      expect(
        container
            .read(bookshelfNotifierProvider)
            .groups
            .map((g) => g.groupName),
        ['全部', '显示组'],
      );
      when(() => shelf.getBook(_book.bookUrl))
          .thenAnswer((_) async => _book.copyWith(durChapterPos: 201));
      await notifier.refreshBook(_book.bookUrl);
      expect(
        container.read(bookshelfNotifierProvider).books.single.durChapterPos,
        201,
      );
      const added = Book(bookUrl: '新书', name: '新增');
      when(() => shelf.addBook(added)).thenAnswer((_) async => added);
      when(() => shelf.deleteBook(added.bookUrl)).thenAnswer((_) async {});
      expect(await notifier.addBook(added), isTrue);
      expect(await notifier.removeBook(added.bookUrl), isTrue);
      expect(
        container.read(bookshelfNotifierProvider).books.single.bookUrl,
        _book.bookUrl,
      );
    });

    test('书架排序失败回读原列表，不留下乐观排序结果', () async {
      when(() => shelf.getBooks())
          .thenAnswer((_) async => [_book, _book.copyWith(bookUrl: '第二本')]);
      final notifier = container.read(bookshelfNotifierProvider.notifier);
      await _flush();
      when(() => shelf.reorderBooks(any())).thenThrow(StateError('排序失败'));
      await notifier.reorderBook(0, 2);
      expect(
        container.read(bookshelfNotifierProvider).books.map((b) => b.bookUrl),
        [_book.bookUrl, '第二本'],
      );
      verify(() => shelf.getBooks()).called(2);
    });

    test('批量删除首本成功次本失败，保留选择与原列表并记录错误', () async {
      when(() => shelf.getBooks())
          .thenAnswer((_) async => [_book, _book.copyWith(bookUrl: '第二本')]);
      final notifier = container.read(bookshelfManageNotifierProvider.notifier);
      await notifier.load();
      notifier.selectAll();
      when(() => shelf.deleteBook(_book.bookUrl)).thenAnswer((_) async {});
      when(() => shelf.deleteBook('第二本')).thenThrow(StateError('第二本删除失败'));
      await notifier.removeSelected();
      final state = container.read(bookshelfManageNotifierProvider);
      expect(state.isBusy, isFalse);
      expect(state.error, contains('第二本删除失败'));
      expect(state.books.length, 2);
      expect(state.selectedUrls.length, 2);
      verify(() => shelf.deleteBook(_book.bookUrl)).called(1);
      verify(() => shelf.getBooks()).called(1);
    });

    test('管理页分组和置顶写入窄接口，成功后回读列表并清空选择', () async {
      final notifier = container.read(bookshelfManageNotifierProvider.notifier);
      await notifier.load();
      notifier.selectAll();
      when(() => shelf.setBookGroup(_book.bookUrl, -3))
          .thenAnswer((_) async {});
      await notifier.moveSelectedToGroup(-3);
      expect(
        container.read(bookshelfManageNotifierProvider).selectedUrls,
        isEmpty,
      );
      notifier.selectAll();
      when(() => shelf.topBook(_book.bookUrl)).thenAnswer((_) async {});
      await notifier.pinSelected();
      verify(() => shelf.setBookGroup(_book.bookUrl, -3)).called(1);
      verify(() => shelf.topBook(_book.bookUrl)).called(1);
      verify(() => shelf.getBooks()).called(3);
    });
  });
}
