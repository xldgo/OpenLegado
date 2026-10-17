import '../../../models/models.dart';

/// 漫画会话的唯一数据快照，滚动和动画状态留在页面。— Codex + UI
class ComicReaderState {
  ComicReaderState({
    required this.bookUrl,
    this.book,
    List<BookChapter> chapters = const [],
    this.chapterIndex = 0,
    List<String> imageUrls = const [],
    this.source,
    Map<String, String> imageHeaders = const {},
    this.loading = true,
    this.error,
    this.chapterError = false,
    this.initialPage = 0,
    this.navigationId = 0,
  }) : chapters = List.unmodifiable(chapters),
       imageUrls = List.unmodifiable(imageUrls),
       imageHeaders = Map.unmodifiable(imageHeaders);

  final String bookUrl;
  final Book? book;
  final List<BookChapter> chapters;
  final int chapterIndex;
  final List<String> imageUrls;
  final BookSource? source;
  final Map<String, String> imageHeaders;
  final bool loading;
  final String? error;
  final bool chapterError;

  /// 本次导航的初始逻辑页，页面自行消费恢复跳转，不作为当前可见页。
  final int initialPage;
  final int navigationId;

  ComicReaderState copyWith({
    Book? book,
    List<BookChapter>? chapters,
    int? chapterIndex,
    List<String>? imageUrls,
    BookSource? source,
    Map<String, String>? imageHeaders,
    bool? loading,
    String? error,
    bool clearError = false,
    bool? chapterError,
    int? initialPage,
    int? navigationId,
  }) => ComicReaderState(
    bookUrl: bookUrl,
    book: book ?? this.book,
    chapters: chapters ?? this.chapters,
    chapterIndex: chapterIndex ?? this.chapterIndex,
    imageUrls: imageUrls ?? this.imageUrls,
    source: source ?? this.source,
    imageHeaders: imageHeaders ?? this.imageHeaders,
    loading: loading ?? this.loading,
    error: clearError ? null : error ?? this.error,
    chapterError: chapterError ?? this.chapterError,
    initialPage: initialPage ?? this.initialPage,
    navigationId: navigationId ?? this.navigationId,
  );
}
