import '../fixtures/app_test_api.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/features/bookshelf/bookshelf.dart';

import '../mocks/mocks.dart';

void main() {
  group('BookshelfManageNotifier', () {
    late MockRustApi mockApi;
    late ProviderContainer container;

    setUpAll(registerFallbacks);

    setUp(() {
      mockApi = MockRustApi();
      container = ProviderContainer(
        overrides: mergeTestOverrides([...mockApi.overrides]),
      );
      addTearDown(container.dispose);
    });

    BookshelfManageState readState() =>
        container.read(bookshelfManageNotifierProvider);
    BookshelfManageNotifier readNotifier() =>
        container.read(bookshelfManageNotifierProvider.notifier);

    void stubBooks(List<Book> books) {
      when(() => mockApi.bookshelfRepository.getBooks())
          .thenAnswer((_) async => books);
    }

    const bookA = Book(bookUrl: 'url-a', name: '书A');
    const bookB = Book(bookUrl: 'url-b', name: '书B');

    test('批量换源跳过本地及同源书，单本失败不阻断其余书籍', () async {
      const first = Book(
        bookUrl: 'first',
        name: '甲',
        author: '作者',
        origin: 'old',
      );
      const failed = Book(bookUrl: 'failed', name: '乙', origin: 'old');
      const same = Book(bookUrl: 'same', name: '同源', origin: 'target');
      const local = Book(
        bookUrl: 'local',
        name: '本地',
        origin: BookType.localTag,
      );
      stubBooks([first, failed, same, local]);
      when(
        () => mockApi.searchService.preciseSearch(
          '甲',
          '作者',
          sourceUrls: ['target'],
        ),
      ).thenAnswer((_) async => const SearchBook(bookUrl: 'target-page'));
      when(
        () => mockApi.searchService.preciseSearch(
          '乙',
          '',
          sourceUrls: ['target'],
        ),
      ).thenThrow(StateError('无候选'));
      when(
        () => mockApi.sourceSwitchService.switchSource(
          'first',
          'target',
          'target-page',
        ),
      ).thenAnswer(
        (_) async =>
            first.copyWith(origin: 'target', originBookUrl: 'target-page'),
      );
      await readNotifier().load();
      readNotifier().selectAll();
      final progress = <String>[];
      final result = await readNotifier().switchSelectedSource(
        'target',
        onProgress: (_, _, name) => progress.add(name),
      );
      expect(result, (1, 2));
      expect(progress, ['甲', '乙']);
      verify(
        () => mockApi.sourceSwitchService.switchSource(
          'first',
          'target',
          'target-page',
        ),
      ).called(1);
      verifyNever(
        () => mockApi.sourceSwitchService.switchSource('failed', any(), any()),
      );
      expect(readState().isBusy, isFalse);
    });

    test('初始状态为空', () {
      final state = readState();
      expect(state.books, isEmpty);
      expect(state.selectedUrls, isEmpty);
      expect(state.isLoading, isFalse);
    });

    test('load 加载书籍并清空勾选', () async {
      stubBooks([bookA, bookB]);

      await readNotifier().load();

      final state = readState();
      expect(state.isLoading, isFalse);
      expect(state.books.length, equals(2));
      expect(state.selectedUrls, isEmpty);
    });

    test('load 异常时兜底并记录 error', () async {
      when(() => mockApi.bookshelfRepository.getBooks())
          .thenThrow(Exception('ffi'));

      await readNotifier().load();

      final state = readState();
      expect(state.isLoading, isFalse);
      expect(state.error, isNotNull);
    });

    test('toggleSelect 勾选与取消', () async {
      stubBooks([bookA, bookB]);
      await readNotifier().load();

      readNotifier().toggleSelect('url-a');
      expect(readState().selectedUrls, equals({'url-a'}));

      readNotifier().toggleSelect('url-a');
      expect(readState().selectedUrls, isEmpty);
    });

    test('selectAll / deselectAll', () async {
      stubBooks([bookA, bookB]);
      await readNotifier().load();

      readNotifier().selectAll();
      expect(readState().selectedUrls, equals({'url-a', 'url-b'}));

      readNotifier().deselectAll();
      expect(readState().selectedUrls, isEmpty);
    });

    test('removeSelected 逐本删除并刷新列表', () async {
      stubBooks([bookA, bookB]);
      await readNotifier().load();
      readNotifier().selectAll();

      when(() => mockApi.bookshelfRepository.deleteBook(any()))
          .thenAnswer((_) async {});
      stubBooks([]); // 删除后列表为空

      await readNotifier().removeSelected();

      verify(() => mockApi.bookshelfRepository.deleteBook('url-a')).called(1);
      verify(() => mockApi.bookshelfRepository.deleteBook('url-b')).called(1);
      final state = readState();
      expect(state.isBusy, isFalse);
      expect(state.books, isEmpty);
      expect(state.selectedUrls, isEmpty);
    });

    test('moveSelectedToGroup 逐本调用 setBookGroup', () async {
      stubBooks([bookA, bookB]);
      await readNotifier().load();
      readNotifier().toggleSelect('url-a');

      when(() => mockApi.bookshelfRepository.setBookGroup(any(), any()))
          .thenAnswer((_) async {});

      await readNotifier().moveSelectedToGroup(4);

      verify(() => mockApi.bookshelfRepository.setBookGroup('url-a', 4))
          .called(1);
      verifyNever(
        () => mockApi.bookshelfRepository.setBookGroup('url-b', any()),
      );
      expect(readState().isBusy, isFalse);
    });

    test('pinSelected 逐本调用 topBook', () async {
      stubBooks([bookA, bookB]);
      await readNotifier().load();
      readNotifier().selectAll();

      when(() => mockApi.bookshelfRepository.topBook(any()))
          .thenAnswer((_) async {});

      await readNotifier().pinSelected();

      verify(() => mockApi.bookshelfRepository.topBook('url-a')).called(1);
      verify(() => mockApi.bookshelfRepository.topBook('url-b')).called(1);
      expect(readState().isBusy, isFalse);
    });

    test('无勾选时批量操作不触发契约', () async {
      await readNotifier().removeSelected();
      await readNotifier().moveSelectedToGroup(1);
      await readNotifier().pinSelected();

      verifyNever(() => mockApi.bookshelfRepository.deleteBook(any()));
      verifyNever(() => mockApi.bookshelfRepository.setBookGroup(any(), any()));
      verifyNever(() => mockApi.bookshelfRepository.topBook(any()));
    });

    test('批量删除异常时兜底并记录 error', () async {
      stubBooks([bookA]);
      await readNotifier().load();
      readNotifier().selectAll();

      when(() => mockApi.bookshelfRepository.deleteBook(any()))
          .thenThrow(Exception('ffi'));

      await readNotifier().removeSelected();

      final state = readState();
      expect(state.isBusy, isFalse);
      expect(state.error, isNotNull);
    });
  });
}
