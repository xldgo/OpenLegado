import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/bootstrap/application_dependencies.dart'
    show bookmarkExportServiceProvider;
import '../../domain/contracts/bookmark_export_service.dart';
import '../../domain/models/bookmark_export_document.dart';
import '../../models/misc.dart';
import '../../platform/files/bookmark_document_saver.dart';

final bookmarkExportProvider = Provider<BookmarkExport>(
  (ref) => BookmarkExport(
    exporter: ref.watch(bookmarkExportServiceProvider),
    saver: const PlatformBookmarkDocumentSaver(),
  ),
);

/// 先生成文档，再交平台保存；不解释或重建导出内容。— Codex + UI
final class BookmarkExport {
  const BookmarkExport({required this.exporter, required this.saver});
  final BookmarkExportService exporter;
  final BookmarkDocumentSaver saver;

  Future<String?> export({
    required String bookName,
    required String bookAuthor,
    required List<Bookmark> bookmarks,
    required BookmarkExportFormat format,
    String? initialDirectory,
  }) async {
    final document = await exporter.buildDocument(
      bookName: bookName,
      bookAuthor: bookAuthor,
      bookmarks: bookmarks,
      format: format,
    );
    return saver.save(document, initialDirectory: initialDirectory);
  }
}
