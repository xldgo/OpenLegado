import 'package:flutter_legado/src/domain/contracts/reading_repository.dart';
import 'package:flutter_legado/src/models/book_chapter.dart';
import 'package:flutter_legado/src/models/book.dart';

/// 场景夹具只覆盖必要读取，其余沿用同一Mock仓储。— Codex + UI
final class TestReadingRepository implements ReadingRepository {
  TestReadingRepository({
    this._delegate,
    this._getChapters,
    this._getChapterContent,
    this._getChapterContentFull,
    this._fetchChapterContent,
    this._refreshToc,
    this._updateReadingProgress,
  });

  final ReadingRepository? _delegate;
  final Future<List<BookChapter>> Function(String)? _getChapters;
  final Future<String> Function(String, int)? _getChapterContent;
  final Future<String> Function(String, int)? _getChapterContentFull;
  final Future<String> Function(String, String, String)? _fetchChapterContent;
  final Future<List<BookChapter>> Function(String, String)? _refreshToc;
  final Future<void> Function({
    required String bookUrl,
    required int chapterIndex,
    required int chapterPos,
  })?
  _updateReadingProgress;
  ReadingRepository get _fallback =>
      _delegate ?? (throw StateError('阅读夹具未配置此操作'));

  @override
  Future<bool> resolveReplaceRule(Book book, bool defaultEnabled) =>
      _fallback.resolveReplaceRule(book, defaultEnabled);
  @override
  Future<List<BookChapter>> getChapters(String bookUrl) =>
      _getChapters?.call(bookUrl) ?? _fallback.getChapters(bookUrl);
  @override
  Future<String> getChapterContent(String bookUrl, int chapterIndex) =>
      _getChapterContent?.call(bookUrl, chapterIndex) ??
      _fallback.getChapterContent(bookUrl, chapterIndex);
  @override
  Future<String> getChapterContentRaw(String bookUrl, int chapterIndex) =>
      _fallback.getChapterContentRaw(bookUrl, chapterIndex);
  @override
  Future<String> getChapterContentFull(String bookUrl, int chapterIndex) =>
      _getChapterContentFull?.call(bookUrl, chapterIndex) ??
      _fallback.getChapterContentFull(bookUrl, chapterIndex);
  @override
  Future<String> fetchChapterContent(
    String bookUrl,
    String chapterUrl,
    String sourceUrl,
  ) =>
      _fetchChapterContent?.call(bookUrl, chapterUrl, sourceUrl) ??
      _fallback.fetchChapterContent(bookUrl, chapterUrl, sourceUrl);
  @override
  Future<bool> saveChapterContent({
    required String bookUrl,
    required int chapterIndex,
    required String title,
    required String content,
  }) => _fallback.saveChapterContent(
    bookUrl: bookUrl,
    chapterIndex: chapterIndex,
    title: title,
    content: content,
  );
  @override
  Future<void> updateReadingProgress({
    required String bookUrl,
    required int chapterIndex,
    required int chapterPos,
  }) =>
      _updateReadingProgress?.call(
        bookUrl: bookUrl,
        chapterIndex: chapterIndex,
        chapterPos: chapterPos,
      ) ??
      _fallback.updateReadingProgress(
        bookUrl: bookUrl,
        chapterIndex: chapterIndex,
        chapterPos: chapterPos,
      );
  @override
  Future<List<BookChapter>> refreshToc(String bookUrl, String sourceUrl) =>
      _refreshToc?.call(bookUrl, sourceUrl) ??
      _fallback.refreshToc(bookUrl, sourceUrl);
}
