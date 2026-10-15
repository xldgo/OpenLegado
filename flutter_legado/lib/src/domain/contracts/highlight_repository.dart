import '../models/book_highlight.dart';

/// 标注实体访问，原文偏移与主键仍由现有契约定义。— Codex + Bridge
abstract interface class HighlightRepository {
  Future<int> highlightAdd(BookHighlight highlight);
  Future<bool> highlightDelete({required int time});
  Future<int> highlightDeleteByBook({required String bookUrl});
  Future<List<BookHighlight>> highlightListByBook({required String bookUrl});
  Future<List<BookHighlight>> highlightListByChapter({
    required String bookUrl,
    required int chapterIndex,
  });
  Future<List<BookHighlight>> highlightSearch({required String keyword});
  Future<List<BookHighlight>> highlightListAll();
}
