import '../bridge/rust_errors.dart';
import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/highlight_repository.dart';
import '../../domain/models/book_highlight.dart';
import '../bridge/reading_dto_mapping.dart';

/// 正式标注通过类型化快照访问现有FRB。— Codex + Bridge
final class RustHighlightRepository implements HighlightRepository {
  const RustHighlightRepository();

  @override
  Future<int> highlightAdd(BookHighlight highlight) async {
    final time = await rustFuture(
      () => bridge.highlightAdd(highlight: bookHighlightToDto(highlight)),
      operation: 'highlightAdd',
    );
    if (time <= 0) throw StateError('保存标注未返回有效主键');
    return time;
  }

  @override
  Future<bool> highlightDelete({required int time}) => rustFuture(
    () => bridge.highlightDelete(time: time),
    operation: 'highlightDelete',
  );

  @override
  Future<int> highlightDeleteByBook({required String bookUrl}) => rustFuture(
    () => bridge.highlightDeleteByBook(bookUrl: bookUrl),
    operation: 'highlightDeleteByBook',
  );

  @override
  Future<List<BookHighlight>> highlightListByBook({
    required String bookUrl,
  }) async => (await rustFuture(
    () => bridge.highlightListByBook(bookUrl: bookUrl),
    operation: 'highlightListByBook',
  )).map(bookHighlightFromDto).toList();

  @override
  Future<List<BookHighlight>> highlightListByChapter({
    required String bookUrl,
    required int chapterIndex,
  }) async => (await rustFuture(
    () => bridge.highlightListByChapter(
      bookUrl: bookUrl,
      chapterIndex: chapterIndex,
    ),
    operation: 'highlightListByChapter',
  )).map(bookHighlightFromDto).toList();

  @override
  Future<List<BookHighlight>> highlightSearch({
    required String keyword,
  }) async => (await rustFuture(
    () => bridge.highlightSearch(keyword: keyword),
    operation: 'highlightSearch',
  )).map(bookHighlightFromDto).toList();

  @override
  Future<List<BookHighlight>> highlightListAll() async => (await rustFuture(
    () => bridge.highlightListAll(),
    operation: 'highlightListAll',
  )).map(bookHighlightFromDto).toList();
}
