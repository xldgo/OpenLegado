import '../../bridge/ffi/ffi.dart' as bridge;
import '../../bridge/file_dto.dart' as dto;
import '../../domain/contracts/bookmark_export_service.dart';
import '../../domain/models/bookmark_export_document.dart';
import '../../models/misc.dart';
import '../bridge/bookmark_dto_mapping.dart';
import '../bridge/rust_errors.dart';

/// 导出规则只在Rust实现，Dart仅映射类型化快照。— Codex + Bridge
final class RustBookmarkExportService implements BookmarkExportService {
  const RustBookmarkExportService();
  @override
  Future<BookmarkExportDocument> buildDocument({
    required String bookName,
    required String bookAuthor,
    required List<Bookmark> bookmarks,
    required BookmarkExportFormat format,
  }) async {
    final document = await rustFuture(
      () => bridge.bookmarkExport(
        bookName: bookName,
        bookAuthor: bookAuthor,
        bookmarks: bookmarks.map(bookmarkToDto).toList(),
        format: switch (format) {
          BookmarkExportFormat.json => dto.BookmarkExportFormatDto.json,
          BookmarkExportFormat.markdown => dto.BookmarkExportFormatDto.markdown,
        },
      ),
      operation: 'bookmarkExport',
    );
    return BookmarkExportDocument(
      fileName: document.fileName,
      mimeType: document.mimeType,
      content: document.content,
    );
  }
}
