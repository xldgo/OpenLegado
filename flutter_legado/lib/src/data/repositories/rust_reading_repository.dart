import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/reading_repository.dart';
import '../../models/book_chapter.dart';
import '../bridge/entity_dto_mapping.dart';
import '../bridge/transport_request_mapping.dart';

/// 直接复用既有FRB，平台载荷由应用装配的处理器执行。— Codex + Bridge
final class RustReadingRepository implements ReadingRepository {
  const RustReadingRepository({required this.dispatchAction});

  final Future<String> Function(Map<String, dynamic>) dispatchAction;

  @override
  Future<List<BookChapter>> getChapters(String bookUrl) async =>
      (await bridge.readerGetChapters(bookUrl: bookUrl)).chapters
          .map(bookChapterFromDto)
          .toList();

  @override
  Future<String> getChapterContent(String bookUrl, int chapterIndex) =>
      bridge.readerGetContent(bookUrl: bookUrl, chapterIndex: chapterIndex);

  @override
  Future<String> getChapterContentRaw(String bookUrl, int chapterIndex) =>
      bridge.readerGetContentRaw(bookUrl: bookUrl, chapterIndex: chapterIndex);

  @override
  Future<String> getChapterContentFull(
    String bookUrl,
    int chapterIndex,
  ) async => resolveTextResponse(
    await bridge.readerGetContentFull(
      bookUrl: bookUrl,
      chapterIndex: chapterIndex,
    ),
    dispatchAction,
  );

  @override
  Future<String> fetchChapterContent(
    String bookUrl,
    String chapterUrl,
    String sourceUrl,
  ) async => resolveTextResponse(
    await bridge.readerFetchContent(
      bookUrl: bookUrl,
      chapterUrl: chapterUrl,
      sourceUrl: sourceUrl,
    ),
    dispatchAction,
  );

  @override
  Future<bool> saveChapterContent({
    required String bookUrl,
    required int chapterIndex,
    required String title,
    required String content,
  }) => bridge.saveChapterContent(
    bookUrl: bookUrl,
    chapterIndex: chapterIndex,
    title: title,
    content: content,
    chapterUrl: '',
  );

  @override
  Future<void> updateReadingProgress({
    required String bookUrl,
    required int chapterIndex,
    required int chapterPos,
  }) => bridge.readerUpdateProgress(
    bookUrl: bookUrl,
    chapterIndex: chapterIndex,
    chapterPos: chapterPos,
  );

  @override
  Future<List<BookChapter>> refreshToc(
    String bookUrl,
    String sourceUrl,
  ) async => (await bridge.readerRefreshToc(
    bookUrl: bookUrl,
    sourceUrl: sourceUrl,
  )).chapters.map(bookChapterFromDto).toList();
}
