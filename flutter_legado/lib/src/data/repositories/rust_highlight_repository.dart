import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/highlight_repository.dart';
import '../../domain/models/book_highlight.dart';
import '../bridge/reading_dto_mapping.dart';

/// 正式标注通过类型化快照访问现有FRB。— Codex + Bridge
final class RustHighlightRepository implements HighlightRepository {
  const RustHighlightRepository();

  @override
  Future<int> highlightAdd(BookHighlight highlight) async {
    final time = await bridge.highlightAdd(
      highlight: bookHighlightToDto(highlight),
    );
    if (time <= 0) throw StateError('保存标注未返回有效主键');
    return time;
  }

  @override
  Future<bool> highlightDelete({required int time}) =>
      bridge.highlightDelete(time: time);

  @override
  Future<int> highlightDeleteByBook({required String bookUrl}) =>
      bridge.highlightDeleteByBook(bookUrl: bookUrl);

  @override
  Future<List<BookHighlight>> highlightListByBook({
    required String bookUrl,
  }) async =>
      (await bridge.highlightListByBook(bookUrl: bookUrl))
          .map(bookHighlightFromDto)
          .toList();

  @override
  Future<List<BookHighlight>> highlightListByChapter({
    required String bookUrl,
    required int chapterIndex,
  }) async => (await bridge.highlightListByChapter(
    bookUrl: bookUrl,
    chapterIndex: chapterIndex,
  )).map(bookHighlightFromDto).toList();

  @override
  Future<List<BookHighlight>> highlightSearch({
    required String keyword,
  }) async =>
      (await bridge.highlightSearch(keyword: keyword))
          .map(bookHighlightFromDto)
          .toList();

  @override
  Future<List<BookHighlight>> highlightListAll() async =>
      (await bridge.highlightListAll()).map(bookHighlightFromDto).toList();
}
