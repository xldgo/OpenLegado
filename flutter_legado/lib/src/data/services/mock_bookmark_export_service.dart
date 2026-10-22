import '../../domain/contracts/bookmark_export_service.dart';
import '../../domain/models/bookmark_export_document.dart';
import '../../models/misc.dart';

/// Mock不复制格式算法，也不生成伪成功的空文件。— Codex + Bridge
final class MockBookmarkExportService implements BookmarkExportService {
  const MockBookmarkExportService();
  @override
  Future<BookmarkExportDocument> buildDocument({
    required String bookName,
    required String bookAuthor,
    required List<Bookmark> bookmarks,
    required BookmarkExportFormat format,
  }) async => throw UnsupportedError('Mock模式不生成书签导出文件，请使用正式引擎');
}
