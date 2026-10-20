import '../../domain/contracts/highlight_repository.dart';
import '../../domain/models/book_highlight.dart';

/// Mock标注集中保存在同一仓储，主键沿用毫秒时间。— Codex + Bridge
final class MockHighlightRepository implements HighlightRepository {
  final Map<int, BookHighlight> _highlights = {};

  @override
  Future<int> highlightAdd(BookHighlight highlight) async {
    var time = highlight.time;
    if (time == 0) {
      time = DateTime.now().millisecondsSinceEpoch;
      while (_highlights.containsKey(time)) {
        time++;
      }
    }
    _highlights[time] = highlight.copyWith(time: time);
    return time;
  }

  @override
  Future<bool> highlightDelete({required int time}) async =>
      _highlights.remove(time) != null;

  @override
  Future<int> highlightDeleteByBook({required String bookUrl}) async {
    final before = _highlights.length;
    _highlights.removeWhere((_, highlight) => highlight.bookUrl == bookUrl);
    return before - _highlights.length;
  }

  @override
  Future<List<BookHighlight>> highlightListByBook({
    required String bookUrl,
  }) async => _sorted(_highlights.values.where((h) => h.bookUrl == bookUrl));

  @override
  Future<List<BookHighlight>> highlightListByChapter({
    required String bookUrl,
    required int chapterIndex,
  }) async => _sorted(
    _highlights.values.where(
      (h) => h.bookUrl == bookUrl && h.chapterIndex == chapterIndex,
    ),
  );

  @override
  Future<List<BookHighlight>> highlightSearch({required String keyword}) async {
    final key = keyword.toLowerCase();
    return _sorted(
      _highlights.values.where(
        (h) =>
            h.chapterName.toLowerCase().contains(key) ||
            h.bookText.toLowerCase().contains(key) ||
            h.note.toLowerCase().contains(key),
      ),
    );
  }

  @override
  Future<List<BookHighlight>> highlightListAll() async =>
      _sorted(_highlights.values, groupByBook: true);

  List<BookHighlight> _sorted(
    Iterable<BookHighlight> items, {
    bool groupByBook = false,
  }) => items.toList()
    ..sort((a, b) {
      for (final order in [
        if (groupByBook) ...[
          a.bookName.toLowerCase().compareTo(b.bookName.toLowerCase()),
          a.bookAuthor.toLowerCase().compareTo(b.bookAuthor.toLowerCase()),
        ],
        a.chapterIndex.compareTo(b.chapterIndex),
        a.chapterPos.compareTo(b.chapterPos),
        a.time.compareTo(b.time),
      ]) {
        if (order != 0) return order;
      }
      return 0;
    });
}
