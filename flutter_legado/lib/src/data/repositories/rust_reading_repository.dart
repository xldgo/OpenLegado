import 'dart:convert';

import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/reading_repository.dart';
import '../../models/book_chapter.dart';

/// 直接复用既有FRB，平台载荷由应用装配的处理器执行。— Codex + Bridge
final class RustReadingRepository implements ReadingRepository {
  const RustReadingRepository({required this._interceptResult});

  final Future<String> Function(String) _interceptResult;

  @override
  Future<List<BookChapter>> getChapters(String bookUrl) async =>
      decodeReadingChapters(
        await bridge.readerGetChapters(bookUrl: bookUrl),
        'getChapters',
      );

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
  ) async => _interceptResult(
    await bridge.readerGetContentFull(
      bookUrl: bookUrl,
      chapterIndex: chapterIndex,
    ),
  );

  @override
  Future<String> fetchChapterContent(
    String bookUrl,
    String chapterUrl,
    String sourceUrl,
  ) async => _interceptResult(
    await bridge.readerFetchContent(
      bookUrl: bookUrl,
      chapterUrl: chapterUrl,
      sourceUrl: sourceUrl,
    ),
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
  ) async => decodeReadingChapters(
    await _interceptResult(
      await bridge.readerRefreshToc(bookUrl: bookUrl, sourceUrl: sourceUrl),
    ),
    'refreshToc',
  );
}

/// 目录支持既有对象或列表；错误响应不得当成合法空目录。
List<BookChapter> decodeReadingChapters(String json, String method) {
  final dynamic decoded = jsonDecode(json);
  final dynamic chapters = decoded is Map<String, dynamic>
      ? decoded['chapters']
      : decoded;
  if (chapters is! List) {
    throw FormatException('$method：目录必须是数组或包含chapters数组的对象');
  }
  return chapters.indexed.map((entry) {
    final (index, chapter) = entry;
    if (chapter is! Map<String, dynamic>) {
      throw FormatException('$method：目录第${index + 1}项必须是对象');
    }
    try {
      return BookChapter.fromJson(chapter);
    } catch (error) {
      throw FormatException('$method：目录第${index + 1}项字段无效（$error）');
    }
  }).toList();
}
