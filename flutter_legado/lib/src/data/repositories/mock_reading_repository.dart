import '../../domain/contracts/reading_repository.dart';
import '../../models/book_chapter.dart';
import 'mock_bookshelf_repository.dart';

/// 与Mock根实例共用书架、目录和正文，不建立独立进度副本。— Codex + Bridge
final class MockReadingRepository implements ReadingRepository {
  MockReadingRepository({
    required this._books,
    required this._chapters,
    required this._contents,
  });

  final MockBookshelfStore _books;
  final Map<String, List<BookChapter>> _chapters;
  final Map<String, Map<int, String>> _contents;

  @override
  Future<List<BookChapter>> getChapters(String bookUrl) async {
    await _books.ensureLoaded();
    return _chapters[bookUrl] ?? [];
  }

  @override
  Future<String> getChapterContent(String bookUrl, int chapterIndex) async {
    await _books.ensureLoaded();
    return _contents[bookUrl]?[chapterIndex] ?? '（暂无内容）';
  }

  @override
  Future<String> getChapterContentRaw(String bookUrl, int chapterIndex) =>
      getChapterContent(bookUrl, chapterIndex);

  @override
  Future<String> getChapterContentFull(String bookUrl, int chapterIndex) async {
    await _books.ensureLoaded();
    return _contents[bookUrl]?[chapterIndex] ?? '（Mock 模式：章节内容）';
  }

  @override
  Future<String> fetchChapterContent(
    String bookUrl,
    String chapterUrl,
    String sourceUrl,
  ) async => '（Mock 模式：网络章节内容）\n\n这是从网络获取的章节正文。';

  @override
  Future<bool> saveChapterContent({
    required String bookUrl,
    required int chapterIndex,
    required String title,
    required String content,
  }) async {
    await _books.ensureLoaded();
    _contents.putIfAbsent(bookUrl, () => <int, String>{})[chapterIndex] =
        content;
    return true;
  }

  @override
  Future<void> updateReadingProgress({
    required String bookUrl,
    required int chapterIndex,
    required int chapterPos,
  }) async {
    await _books.ensureLoaded();
    final index = _books.books.indexWhere((book) => book.bookUrl == bookUrl);
    if (index >= 0) {
      _books.books[index] = _books.books[index].copyWith(
        durChapterIndex: chapterIndex,
        durChapterPos: chapterPos,
      );
    }
  }

  @override
  Future<List<BookChapter>> refreshToc(String bookUrl, String sourceUrl) =>
      getChapters(bookUrl);
}
