import '../../utils/error_message.dart';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/book_detail_service.dart';
import '../../domain/models/book_detail_data.dart';
import '../../models/models.dart';
import '../../features/bookshelf/bookshelf_repositories.dart';
import '../../features/book_sources/book_source_repository_provider.dart';
import '../../providers/reading_provider.dart';
import '../../providers/explore/explore_dependencies.dart';
import 'book_detail_state.dart';

final bookDetailServiceProvider = Provider<BookDetailService>(
  (ref) => BookDetailService(
    bookshelf: ref.watch(bookshelfRepositoryProvider),
    reading: ref.watch(readingRepositoryProvider),
    sources: ref.watch(bookSourceRepositoryProvider),
    query: ref.watch(bookSourceQueryServiceProvider),
    log: debugPrint,
  ),
);

final bookDetailProvider = NotifierProvider.autoDispose
    .family<BookDetailNotifier, BookDetailState, BookDetailRequest>(
      BookDetailNotifier.new,
    );

/// 详情状态不持有Widget、导航或平台弹层。— Codex + UI
class BookDetailNotifier extends Notifier<BookDetailState> {
  BookDetailNotifier(this.request);
  final BookDetailRequest request;
  int _generation = 0;

  @override
  BookDetailState build() {
    ref.onDispose(() => _generation++);
    return BookDetailState(
      data: BookDetailData(book: request.book),
      pageLoading: request.book == null && request.bookUrl.isEmpty,
    );
  }

  Future<void> load() async {
    if (!ref.mounted) return;
    final generation = ++_generation;
    bool isCurrent() => ref.mounted && generation == _generation;
    final service = ref.read(bookDetailServiceProvider);
    state = state.copyWith(
      pageLoading: state.data.book == null,
      tocLoading: false,
      networkLoading: false,
      clearError: true,
    );
    try {
      final data = await service.readLocal(request);
      if (!isCurrent()) return;
      final complete = service.needsCompletion(data);
      state = state.copyWith(
        data: data,
        pageLoading: false,
        tocLoading: complete && data.chapters.isEmpty,
        networkLoading: complete,
      );
      if (complete) {
        await for (final update in service.complete(
          data,
          isCurrent: isCurrent,
        )) {
          if (!isCurrent()) return;
          state = state.copyWith(data: update);
        }
      }
      if (!isCurrent()) return;
      state = state.copyWith(
        pageLoading: false,
        tocLoading: false,
        networkLoading: false,
        completedLoads: state.completedLoads + 1,
      );
    } catch (error) {
      if (!isCurrent()) return;
      state = state.copyWith(
        pageLoading: false,
        tocLoading: false,
        networkLoading: false,
        error: errorMessage(error),
      );
    }
  }

  Future<List<BookChapter>> refreshChapters() async {
    final generation = ++_generation;
    final service = ref.read(bookDetailServiceProvider);
    final data = state.data;
    state = state.copyWith(
      tocLoading: true,
      networkLoading: true,
      clearError: true,
    );
    try {
      final chapters = await service.refreshChapters(data);
      if (ref.mounted && generation == _generation) {
        state = state.copyWith(data: state.data.copyWith(chapters: chapters));
      }
      return chapters;
    } finally {
      if (ref.mounted && generation == _generation) {
        state = state.copyWith(tocLoading: false, networkLoading: false);
      }
    }
  }

  void updateBook(Book book) =>
      state = state.copyWith(data: state.data.copyWith(book: book));
  void updateSource(BookSource source) =>
      state = state.copyWith(data: state.data.copyWith(source: source));
  void updateShelfMembership(bool value) =>
      state = state.copyWith(data: state.data.copyWith(inBookshelf: value));
}

String detailErrorMessage(Object error) => errorMessage(error);
