import '../../models/misc.dart';
import '../models/bookmark_export_document.dart';

/// 只生成导出文档，目录选择、保存与分享由平台层负责。— Codex + Bridge
abstract interface class BookmarkExportService {
  Future<BookmarkExportDocument> buildDocument({
    required String bookName,
    required String bookAuthor,
    required List<Bookmark> bookmarks,
    required BookmarkExportFormat format,
  });
}
