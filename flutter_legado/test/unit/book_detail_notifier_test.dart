import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_legado/src/features/book_detail/book_detail_notifier.dart';
import 'package:flutter_legado/src/features/bookshelf/bookshelf_repositories.dart';
import 'package:flutter_legado/src/models/models.dart';

import '../fixtures/book_detail_fixture.dart';
import '../mocks/mocks.dart';

void main() {
  setUpAll(registerFallbacks);
  late BookDetailFixture fixture;
  late ProviderContainer container;
  final provider = bookDetailProvider((
    bookUrl: BookDetailFixture.book.bookUrl,
    book: BookDetailFixture.book,
  ));
  setUp(() {
    fixture = BookDetailFixture();
    container = ProviderContainer(
      overrides: [
        bookDetailServiceProvider.overrideWithValue(fixture.service),
        bookshelfRepositoryProvider.overrideWithValue(fixture.bookshelf),
      ],
    );
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    addTearDown(container.dispose);
  });

  test('路由书立即可见，本地目录先显示，后台刷新完成才清除进度', () async {
    final info = Completer<Book>();
    fixture.stored = BookDetailFixture.book;
    fixture.cachedChapters = [BookDetailFixture.chapter];
    when(
      () => fixture.query.getBookInfo(
        any(),
        any(),
        existingBook: any(named: 'existingBook'),
        canReName: any(named: 'canReName'),
      ),
    ).thenAnswer((_) => info.future);
    expect(container.read(provider).data.book, BookDetailFixture.book);
    final pending = container.read(provider.notifier).load();
    await Future<void>.delayed(Duration.zero);
    expect(container.read(provider).data.chapters, [BookDetailFixture.chapter]);
    expect(container.read(provider).pageLoading, isFalse);
    expect(container.read(provider).networkLoading, isTrue);
    expect(container.read(provider).tocLoading, isFalse);
    info.complete(BookDetailFixture.fresh);
    await pending;
    expect(container.read(provider).data.book!.name, '新书名');
    expect(container.read(provider).networkLoading, isFalse);
  });

  test('首次失败可重试，错误清除并恢复详情', () async {
    when(() => fixture.bookshelf.getBook(any())).thenThrow(StateError('读取失败'));
    final notifier = container.read(provider.notifier);
    await notifier.load();
    expect(container.read(provider).error, contains('读取失败'));
    expect(container.read(provider).networkLoading, isFalse);
    expect(container.read(provider).pageLoading, isFalse);
    when(() => fixture.bookshelf.getBook(any())).thenAnswer((_) async => null);
    await notifier.load();
    expect(container.read(provider).error, isNull);
    expect(container.read(provider).networkLoading, isFalse);
    expect(container.read(provider).data.chapters, [BookDetailFixture.chapter]);
  });

  test('连续刷新只允许最新请求写入，旧结果不覆盖新详情', () async {
    final old = Completer<Book>();
    var calls = 0;
    fixture.cachedChapters = [BookDetailFixture.chapter];
    when(
      () => fixture.query.getBookInfo(
        any(),
        any(),
        existingBook: any(named: 'existingBook'),
        canReName: any(named: 'canReName'),
      ),
    ).thenAnswer((_) async {
      if (++calls == 1) return old.future;
      return BookDetailFixture.fresh.copyWith(name: '第二次详情');
    });
    final notifier = container.read(provider.notifier);
    final first = notifier.load();
    await Future<void>.delayed(Duration.zero);
    await notifier.load();
    old.complete(BookDetailFixture.fresh.copyWith(name: '过期详情'));
    await first;
    expect(container.read(provider).data.book!.name, '第二次详情');
    expect(container.read(provider).networkLoading, isFalse);
  });

  test('菜单更新复用同一详情快照，刷新目录也写入同一状态', () async {
    final notifier = container.read(provider.notifier);
    notifier.updateBook(
      BookDetailFixture.book.copyWith(customCoverUrl: 'custom-cover'),
    );
    notifier.updateShelfMembership(true);
    notifier.updateSource(BookDetailFixture.source);
    expect(container.read(provider).data.book!.customCoverUrl, 'custom-cover');
    expect(container.read(provider).data.inBookshelf, isTrue);
    await notifier.refreshChapters();
    expect(container.read(provider).data.chapters, [BookDetailFixture.chapter]);
    expect(container.read(provider).tocLoading, isFalse);
    verify(
      () => fixture.reading.refreshToc(
        BookDetailFixture.book.bookUrl,
        BookDetailFixture.book.origin,
      ),
    ).called(1);
  });

  test('刷新目录失败保持原目录并向交互调用方传播错误', () async {
    await container.read(provider.notifier).load();
    when(
      () => fixture.query.getChapters(
        any(),
        any(),
        bookUrl: any(named: 'bookUrl'),
        tocUrl: any(named: 'tocUrl'),
        bookName: any(named: 'bookName'),
      ),
    ).thenThrow(StateError('目录失败'));
    await expectLater(
      container.read(provider.notifier).refreshChapters(),
      throwsStateError,
    );
    expect(container.read(provider).data.chapters, [BookDetailFixture.chapter]);
    expect(container.read(provider).networkLoading, isFalse);
  });

  test('离开作用域后迟到加载不发布状态或写回书籍', () async {
    final info = Completer<Book>();
    fixture.stored = BookDetailFixture.book;
    fixture.cachedChapters = [BookDetailFixture.chapter];
    when(
      () => fixture.query.getBookInfo(
        any(),
        any(),
        existingBook: any(named: 'existingBook'),
        canReName: any(named: 'canReName'),
      ),
    ).thenAnswer((_) => info.future);
    final pending = container.read(provider.notifier).load();
    await Future<void>.delayed(Duration.zero);
    container.invalidate(provider);
    info.complete(BookDetailFixture.fresh);
    await pending;
    verifyNever(() => fixture.bookshelf.updateBook(any()));
  });
  test('自动更新保存完成后接收最新快照，保存失败保留原状态', () async {
    final notifier = container.read(provider.notifier);
    notifier.updateShelfMembership(true);
    final pending = Completer<Book>();
    when(
      () =>
          fixture.bookshelf.setCanUpdate(BookDetailFixture.book.bookUrl, false),
    ).thenAnswer((_) => pending.future);
    final save = notifier.setCanUpdate(false);
    expect(container.read(provider).data.book!.canUpdate, isTrue);
    final latest = BookDetailFixture.book.copyWith(
      canUpdate: false,
      name: '存储中的最新书名',
    );
    pending.complete(latest);
    await save;
    expect(container.read(provider).data.book, latest);
    when(() => fixture.bookshelf.setCanUpdate(latest.bookUrl, true))
        .thenThrow(StateError('写入失败'));
    await expectLater(notifier.setCanUpdate(true), throwsStateError);
    expect(container.read(provider).data.book, latest);
    verifyNever(() => fixture.bookshelf.updateBook(any()));
  });

  test('未入架切换仅影响临时状态，不保存或清除更新错误', () async {
    final notifier = container.read(provider.notifier);
    notifier.updateBook(
      BookDetailFixture.book.copyWith(
        bookType: BookType.text | BookType.updateError,
      ),
    );
    await notifier.setCanUpdate(false);
    expect(container.read(provider).data.book!.canUpdate, isFalse);
    expect(
      container.read(provider).data.book!.bookType & BookType.updateError,
      isNot(0),
    );
    verifyNever(() => fixture.bookshelf.setCanUpdate(any(), any()));
    verifyNever(() => fixture.bookshelf.updateBook(any()));
  });
}
