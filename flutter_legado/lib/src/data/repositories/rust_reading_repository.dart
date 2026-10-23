import '../bridge/rust_errors.dart';
import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/reading_repository.dart';
import '../../models/book_chapter.dart';
import '../../models/book.dart';
import '../bridge/entity_dto_mapping.dart';
import '../bridge/transport_request_mapping.dart';

/// 直接复用既有FRB，平台载荷由应用装配的处理器执行。— Codex + Bridge
final class RustReadingRepository implements ReadingRepository {
  const RustReadingRepository({required this.dispatchAction});

  final Future<String> Function(Map<String, dynamic>) dispatchAction;

  @override
  Future<bool> resolveReplaceRule(Book book, bool defaultEnabled) => rustFuture(
    () => bridge.readerResolveReplaceRule(
      book: bookToDto(book),
      defaultEnabled: defaultEnabled,
    ),
    operation: 'readerResolveReplaceRule',
  );

  @override
  Future<List<BookChapter>> getChapters(String bookUrl) async =>
      (await rustFuture(
        () => bridge.readerGetChapters(bookUrl: bookUrl),
        operation: 'readerGetChapters',
      )).chapters.map(bookChapterFromDto).toList();

  @override
  Future<String> getChapterContent(String bookUrl, int chapterIndex) =>
      rustFuture(
        () => bridge.readerGetContent(
          bookUrl: bookUrl,
          chapterIndex: chapterIndex,
        ),
        operation: 'readerGetContent',
      );

  @override
  Future<String> getChapterContentRaw(String bookUrl, int chapterIndex) =>
      rustFuture(
        () => bridge.readerGetContentRaw(
          bookUrl: bookUrl,
          chapterIndex: chapterIndex,
        ),
        operation: 'readerGetContentRaw',
      );

  @override
  Future<String> getChapterContentFull(
    String bookUrl,
    int chapterIndex,
  ) async => resolveTextResponse(
    await rustFuture(
      () => bridge.readerGetContentFull(
        bookUrl: bookUrl,
        chapterIndex: chapterIndex,
      ),
      operation: 'readerGetContentFull',
    ),
    dispatchAction,
  );

  @override
  Future<String> fetchChapterContent(
    String bookUrl,
    String chapterUrl,
    String sourceUrl,
  ) async => resolveTextResponse(
    await rustFuture(
      () => bridge.readerFetchContent(
        bookUrl: bookUrl,
        chapterUrl: chapterUrl,
        sourceUrl: sourceUrl,
      ),
      operation: 'readerFetchContent',
    ),
    dispatchAction,
  );

  @override
  Future<bool> saveChapterContent({
    required String bookUrl,
    required int chapterIndex,
    required String title,
    required String content,
  }) => rustFuture(
    () => bridge.saveChapterContent(
      bookUrl: bookUrl,
      chapterIndex: chapterIndex,
      title: title,
      content: content,
      chapterUrl: '',
    ),
    operation: 'saveChapterContent',
  );

  @override
  Future<void> updateReadingProgress({
    required String bookUrl,
    required int chapterIndex,
    required int chapterPos,
  }) => rustFuture(
    () => bridge.readerUpdateProgress(
      bookUrl: bookUrl,
      chapterIndex: chapterIndex,
      chapterPos: chapterPos,
    ),
    operation: 'readerUpdateProgress',
  );

  @override
  Future<List<BookChapter>> refreshToc(
    String bookUrl,
    String sourceUrl,
  ) async => (await rustFuture(
    () => bridge.readerRefreshToc(bookUrl: bookUrl, sourceUrl: sourceUrl),
    operation: 'readerRefreshToc',
  )).chapters.map(bookChapterFromDto).toList();
}
