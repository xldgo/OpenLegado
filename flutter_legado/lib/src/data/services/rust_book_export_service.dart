import '../bridge/rust_errors.dart';

import 'dart:convert';

import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/book_export_service.dart';
import '../../domain/models/book_content_result.dart';
import '../bridge/file_dto_mapping.dart';

/// 导出选项和传输编码只在适配器处理。— Codex + Bridge
final class RustBookExportService implements BookExportService {
  const RustBookExportService();
  @override
  Future<BookExportData> bookExportWithOptions({
    required String bookUrl,
    required String format,
    required bool includeToc,
    BookExportOptions options = const BookExportOptions(),
  }) async {
    final values = <String, dynamic>{
      'encoding': ?options.encoding,
      'startChapter': ?options.startChapter,
      'endChapter': ?options.endChapter,
      'fileNameTemplate': ?options.fileNameTemplate,
    };
    return bookExportFromDto(
      await rustFuture(
        () => bridge.bookExportWithOptions(
          bookUrl: bookUrl,
          format: format,
          includeToc: includeToc,
          optionsJson: values.isEmpty ? '' : jsonEncode(values),
        ),
        operation: 'bookExportWithOptions',
      ),
    );
  }

  @override
  Future<BookExportInfo> bookExportInfo({
    required String bookUrl,
    required String format,
  }) async => bookExportInfoFromDto(
    await rustFuture(
      () => bridge.bookExportInfo(bookUrl: bookUrl, format: format),
      operation: 'bookExportInfo',
    ),
  );
}
