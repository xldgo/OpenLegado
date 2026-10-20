import '../models/book_content_result.dart';

/// 导出内容和预览，文件保存与WebDAV交由调用层编排。— Codex + Bridge
abstract interface class BookExportService {
  Future<BookExportData> bookExportWithOptions({
    required String bookUrl,
    required String format,
    required bool includeToc,
    BookExportOptions options = const BookExportOptions(),
  });
  Future<BookExportInfo> bookExportInfo({
    required String bookUrl,
    required String format,
  });
}
