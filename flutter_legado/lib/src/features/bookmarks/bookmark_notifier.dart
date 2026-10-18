import '../../utils/error_message.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../../models/models.dart';
import 'bookmark_repository_provider.dart';
import 'bookmark_state.dart';

/// 书签 Riverpod Notifier
///
/// 职责严格限定（对齐原 BookmarkProvider 行为）：
/// - 调用 BookmarkRepository → 接收纯数据 → 更新 immutable State
/// - 管理 UI 状态（loading/error/data 三态）
/// - 加载全部 / 按书名+作者加载 / 搜索 / 增删书签
/// - 不自动加载（由界面在 initState 后主动调用 [loadAll]）
class BookmarkNotifier extends Notifier<BookmarkState> {
  @override
  BookmarkState build() {
    // 原实现不自动加载，保持惰性：由界面主动触发 loadAll/loadByBook
    return const BookmarkState();
  }

  /// 加载所有书签
  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final repository = ref.read(bookmarkRepositoryProvider);
      final bookmarks = await repository.getAllBookmarks();
      state = state.copyWith(bookmarks: bookmarks, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: errorMessage(e), isLoading: false);
    }
  }

  /// 按书名+作者加载书签（契约 §2.7 getBookmarksByBook，台账 §5.14-2，
  /// Task #65；对齐原版 bookmarkDao.getByBook(name, author)，规避同名书混入）
  Future<void> loadByBook(String bookName, String bookAuthor) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final repository = ref.read(bookmarkRepositoryProvider);
      final bookmarks = await repository.getBookmarksByBook(
        bookName,
        bookAuthor,
      );
      state = state.copyWith(bookmarks: bookmarks, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: errorMessage(e), isLoading: false);
    }
  }

  /// 添加书签（插入列表头部）
  Future<Bookmark> addBookmark({
    required String bookName,
    required String bookAuthor,
    required int chapterIndex,
    required int chapterPos,
    required String chapterName,
    String bookText = '',
    String content = '',
  }) async {
    final bm = Bookmark(
      bookName: bookName,
      bookAuthor: bookAuthor,
      chapterIndex: chapterIndex,
      chapterPos: chapterPos,
      chapterName: chapterName,
      bookText: bookText,
      content: content,
    );
    final repository = ref.read(bookmarkRepositoryProvider);
    final added = await repository.addBookmark(bm);
    state = state.copyWith(bookmarks: [added, ...state.bookmarks]);
    return added;
  }

  /// 只更新备注，持久化成功后刷新列表，保留原文与阅读位置。— Codex + UI
  Future<void> updateNote(Bookmark bookmark, String note) async {
    final repository = ref.read(bookmarkRepositoryProvider);
    await repository.updateBookmark(bookmark.copyWith(content: note));
    state = state.copyWith(
      bookmarks: [
        for (final current in state.bookmarks)
          if (current.id == bookmark.id)
            current.copyWith(content: note)
          else
            current,
      ],
    );
  }

  /// 删除书签
  Future<void> deleteBookmark(int id) async {
    final repository = ref.read(bookmarkRepositoryProvider);
    await repository.deleteBookmark(id);
    state = state.copyWith(
      bookmarks: state.bookmarks.where((b) => b.id != id).toList(),
    );
  }

  /// 搜索书签（空关键词回退到加载全部）
  Future<void> search(String keyword) async {
    if (keyword.isEmpty) {
      await loadAll();
      return;
    }
    state = state.copyWith(isLoading: true, error: null);
    try {
      final repository = ref.read(bookmarkRepositoryProvider);
      final bookmarks = await repository.searchBookmarks(keyword);
      state = state.copyWith(bookmarks: bookmarks, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: errorMessage(e), isLoading: false);
    }
  }
}

/// 书签 Notifier 全局 Provider
///
/// 使用方式：
/// ```dart
/// final state = ref.watch(bookmarkNotifierProvider);
/// ref.read(bookmarkNotifierProvider.notifier).loadAll();
/// ```
final bookmarkNotifierProvider =
    NotifierProvider<BookmarkNotifier, BookmarkState>(BookmarkNotifier.new);
