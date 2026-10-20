import 'dart:convert';

import '../../domain/contracts/book_export_service.dart';
import '../../domain/contracts/bookshelf_repository.dart';
import '../../domain/contracts/reading_repository.dart';
import '../../domain/models/book_content_result.dart';

/// 读应用装配的同一书架与目录，不复制书籍状态。— Codex + Bridge
final class MockBookExportService implements BookExportService {
  const MockBookExportService({
    required this._bookshelf,
    required this._reading,
  });
  final BookshelfRepository _bookshelf;
  final ReadingRepository _reading;
  @override
  Future<BookExportData> bookExportWithOptions({
    required String bookUrl,
    required String format,
    required bool includeToc,
    BookExportOptions options = const BookExportOptions(),
  }) async {
    final book = await _bookshelf.getBook(bookUrl);
    if (book == null) throw StateError('书籍不存在: $bookUrl');
    return BookExportData(
      fileName: '${book.name}.$format',
      bytes: utf8.encode('Mock 导出内容'),
      mimeType: 'text/plain',
    );
  }

  @override
  Future<BookExportInfo> bookExportInfo({
    required String bookUrl,
    required String format,
  }) async {
    final book = await _bookshelf.getBook(bookUrl);
    if (book == null) throw StateError('书籍不存在: $bookUrl');
    return BookExportInfo(
      fileName: '${book.name}.$format',
      chapterCount: (await _reading.getChapters(bookUrl)).length,
    );
  }
}
