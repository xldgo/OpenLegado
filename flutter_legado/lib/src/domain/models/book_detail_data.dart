import '../../models/book.dart';
import '../../models/book_chapter.dart';
import '../../models/book_source.dart';

/// 详情查询参数保留路由快照与稳定主键。— Codex + UI
typedef BookDetailRequest = ({String bookUrl, Book? book});

/// 详情数据不携带页面、导航或加载控件状态。— Codex + Bridge
class BookDetailData {
  BookDetailData({
    this.book,
    List<BookChapter> chapters = const [],
    this.source,
    this.inBookshelf = false,
  }) : chapters = List.unmodifiable(chapters);

  final Book? book;
  final List<BookChapter> chapters;
  final BookSource? source;
  final bool inBookshelf;

  BookDetailData copyWith({
    Book? book,
    List<BookChapter>? chapters,
    BookSource? source,
    bool? inBookshelf,
  }) => BookDetailData(
    book: book ?? this.book,
    chapters: chapters ?? this.chapters,
    source: source ?? this.source,
    inBookshelf: inBookshelf ?? this.inBookshelf,
  );
}
