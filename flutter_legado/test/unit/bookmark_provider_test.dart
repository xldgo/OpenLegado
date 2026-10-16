library;

/// BookmarkNotifier 单元测试
///
/// 覆盖：初始状态/loadAll/loadByBook/addBookmark/deleteBookmark/search
///
/// Riverpod 范式：ProviderContainer + bookmarkRepositoryProvider override。
/// 注意：Riverpod 仅在 state 实际变化时通知监听者（不同于 ChangeNotifier
/// 每次 notifyListeners 必发），故「触发通知」用例改用 container.listen
/// 并先制造真实状态变化再断言。

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/bridge/ffi.dart';
import 'package:flutter_legado/src/features/bookmarks/bookmarks.dart';
import 'package:flutter_legado/src/domain/contracts/bookmark_repository.dart';

/// 单独模拟书签接口，不依赖原生库或巨大 TestApi。— Codex + UI
class _MockBookmarkRepository extends Mock implements BookmarkRepository {}

void main() {
  late _MockBookmarkRepository repository;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(const Bookmark());
  });

  setUp(() {
    repository = _MockBookmarkRepository();
    container = ProviderContainer(
      overrides: [bookmarkRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
  });

  BookmarkState readState() => container.read(bookmarkNotifierProvider);
  BookmarkNotifier readNotifier() =>
      container.read(bookmarkNotifierProvider.notifier);

  group('BookmarkNotifier 初始状态', () {
    test('初始书签列表为空', () {
      expect(readState().bookmarks, isEmpty);
    });

    test('初始非加载状态', () {
      expect(readState().isLoading, isFalse);
    });

    test('初始无错误', () {
      expect(readState().error, isNull);
    });
  });

  group('BookmarkNotifier loadAll', () {
    test('成功加载所有书签', () async {
      final bookmarks = [
        const Bookmark(id: 1, bookName: '书1', chapterName: '第1章'),
        const Bookmark(id: 2, bookName: '书2', chapterName: '第5章'),
      ];
      when(() => repository.getAllBookmarks())
          .thenAnswer((_) async => bookmarks);

      await readNotifier().loadAll();

      expect(readState().bookmarks.length, equals(2));
      expect(readState().isLoading, isFalse);
      expect(readState().error, isNull);
    });

    test('加载失败设置 BridgeError', () async {
      when(() => repository.getAllBookmarks())
          .thenThrow(const BridgeError(message: '书签加载失败'));

      await readNotifier().loadAll();

      expect(readState().error, equals('书签加载失败'));
      expect(readState().isLoading, isFalse);
    });

    test('加载失败设置普通异常', () async {
      when(() => repository.getAllBookmarks()).thenThrow(Exception('网络'));

      await readNotifier().loadAll();

      expect(readState().error, contains('网络'));
    });

    test('loadAll 触发状态变更通知', () async {
      when(() => repository.getAllBookmarks())
          .thenAnswer((_) async => [const Bookmark(id: 1, bookName: '书1')]);
      var notifyCount = 0;
      // 先建立监听（fireImmediately 仅回放当前值，不计入变更次数）
      container.listen<BookmarkState>(
        bookmarkNotifierProvider,
        (prev, next) => notifyCount++,
      );

      await readNotifier().loadAll();

      // 真实状态变化：isLoading true→false 且 bookmarks 由空变非空
      expect(notifyCount, greaterThanOrEqualTo(2));
    });
  });

  group('BookmarkNotifier loadByBook', () {
    test('按书名+作者加载书签', () async {
      final bookmarks = [
        const Bookmark(id: 1, bookName: '斗破苍穹', chapterName: '第1章'),
      ];
      // [Task #65] 书签查询改用 getBookmarksByBook（契约 §2.7，台账 §5.14-2）
      when(() => repository.getBookmarksByBook(any(), any()))
          .thenAnswer((_) async => bookmarks);

      await readNotifier().loadByBook('斗破苍穹', '天蚕土豆');

      expect(readState().bookmarks.length, equals(1));
      expect(readState().bookmarks[0].bookName, equals('斗破苍穹'));
    });

    test('按书名+作者加载失败设置错误', () async {
      when(() => repository.getBookmarksByBook(any(), any()))
          .thenThrow(const BridgeError(message: '查询失败'));

      await readNotifier().loadByBook('不存在的书', '');

      expect(readState().error, equals('查询失败'));
    });
  });

  group('BookmarkNotifier addBookmark', () {
    test('添加失败不改变已有状态，异常传播给调用方', () async {
      const existing = Bookmark(id: 1, time: 123, content: '保留');
      when(() => repository.getAllBookmarks())
          .thenAnswer((_) async => [existing]);
      await readNotifier().loadAll();
      final before = readState();
      final failure = StateError('添加失败');
      when(() => repository.addBookmark(any()))
          .thenAnswer((_) async => throw failure);

      await expectLater(
        readNotifier().addBookmark(
          bookName: '书',
          bookAuthor: '作者',
          chapterIndex: 1,
          chapterPos: 42,
          chapterName: '章',
        ),
        throwsA(same(failure)),
      );
      expect(readState(), same(before));
    });

    test('添加书签成功插入列表头部', () async {
      // 先加载一个书签
      when(() => repository.getAllBookmarks())
          .thenAnswer((_) async => [const Bookmark(id: 1, bookName: '旧书')]);
      await readNotifier().loadAll();

      const newBookmark = Bookmark(
        id: 2,
        bookName: '新书',
        bookAuthor: '作者',
        chapterIndex: 5,
        chapterPos: 100,
        chapterName: '第5章',
        bookText: '一些文本',
        content: '备注',
      );
      when(() => repository.addBookmark(any()))
          .thenAnswer((_) async => newBookmark);

      final result = await readNotifier().addBookmark(
        bookName: '新书',
        bookAuthor: '作者',
        chapterIndex: 5,
        chapterPos: 100,
        chapterName: '第5章',
        bookText: '一些文本',
        content: '备注',
      );

      expect(result.id, equals(2));
      expect(readState().bookmarks.length, equals(2));
      // 新书签在头部
      expect(readState().bookmarks[0].bookName, equals('新书'));
    });
  });

  group('BookmarkNotifier updateNote', () {
    const original = Bookmark(
      id: 1,
      time: 12345,
      bookName: '书',
      bookAuthor: '作者',
      chapterIndex: 2,
      chapterPos: 102,
      chapterName: '章',
      bookText: '原文',
      content: '旧备注',
    );
    const other = Bookmark(id: 2, content: '其他记录');

    test('成功后只更新备注，允许清空，其他字段与记录保留', () async {
      when(() => repository.getAllBookmarks())
          .thenAnswer((_) async => [original, other]);
      when(() => repository.updateBookmark(any())).thenAnswer((_) async {});
      await readNotifier().loadAll();
      await readNotifier().updateNote(original, '新备注');
      expect(readState().bookmarks, [original.copyWith(content: '新备注'), other]);
      verify(() => repository.updateBookmark(original.copyWith(content: '新备注')))
          .called(1);

      await readNotifier().updateNote(original, '');
      expect(readState().bookmarks, [original.copyWith(content: ''), other]);
      verify(() => repository.updateBookmark(original.copyWith(content: '')))
          .called(1);
    });

    test('等待持久化成功才刷新，失败保留当前状态并传播异常', () async {
      when(() => repository.getAllBookmarks())
          .thenAnswer((_) async => [original, other]);
      await readNotifier().loadAll();
      final before = readState();
      final gate = Completer<void>();
      when(() => repository.updateBookmark(any()))
          .thenAnswer((_) => gate.future);
      final pending = readNotifier().updateNote(original, '新备注');
      expect(readState(), same(before));
      final failure = StateError('保存失败');
      final result = expectLater(pending, throwsA(same(failure)));
      gate.completeError(failure);
      await result;
      expect(readState(), same(before));
    });

    test('异步期间切换列表，不把更新记录插入其他书的结果', () async {
      when(() => repository.getAllBookmarks())
          .thenAnswer((_) async => [original]);
      when(() => repository.getBookmarksByBook('另一书', '作者'))
          .thenAnswer((_) async => [other]);
      final gate = Completer<void>();
      when(() => repository.updateBookmark(any()))
          .thenAnswer((_) => gate.future);
      await readNotifier().loadAll();
      final pending = readNotifier().updateNote(original, '新备注');
      await readNotifier().loadByBook('另一书', '作者');
      gate.complete();
      await pending;
      expect(readState().bookmarks, [other]);
    });
  });

  group('BookmarkNotifier deleteBookmark', () {
    test('删除失败保留列表，异常传播给调用方', () async {
      const existing = Bookmark(id: 1, time: 123, content: '保留');
      when(() => repository.getAllBookmarks())
          .thenAnswer((_) async => [existing]);
      await readNotifier().loadAll();
      final before = readState();
      final failure = StateError('删除失败');
      when(() => repository.deleteBookmark(1))
          .thenAnswer((_) async => throw failure);

      await expectLater(
        readNotifier().deleteBookmark(1),
        throwsA(same(failure)),
      );
      expect(readState(), same(before));
    });

    test('删除书签成功移除', () async {
      when(() => repository.getAllBookmarks()).thenAnswer(
        (_) async => [
          const Bookmark(id: 1, bookName: '书1'),
          const Bookmark(id: 2, bookName: '书2'),
        ],
      );
      await readNotifier().loadAll();

      when(() => repository.deleteBookmark(any())).thenAnswer((_) async {});

      await readNotifier().deleteBookmark(1);

      expect(readState().bookmarks.length, equals(1));
      expect(readState().bookmarks[0].id, equals(2));
    });
  });

  group('BookmarkNotifier search', () {
    test('关键字搜索', () async {
      final results = [
        const Bookmark(id: 1, bookName: '搜索目标', chapterName: '第1章'),
      ];
      when(() => repository.searchBookmarks(any()))
          .thenAnswer((_) async => results);

      await readNotifier().search('目标');

      expect(readState().bookmarks.length, equals(1));
      expect(readState().isLoading, isFalse);
    });

    test('空关键字调用 loadAll', () async {
      when(() => repository.getAllBookmarks())
          .thenAnswer((_) async => [const Bookmark(id: 1, bookName: '全部')]);

      await readNotifier().search('');

      expect(readState().bookmarks.length, equals(1));
      verify(() => repository.getAllBookmarks()).called(1);
    });

    test('搜索失败设置错误', () async {
      when(() => repository.searchBookmarks(any()))
          .thenThrow(const BridgeError(message: '搜索出错'));

      await readNotifier().search('test');

      expect(readState().error, equals('搜索出错'));
    });
  });
}
