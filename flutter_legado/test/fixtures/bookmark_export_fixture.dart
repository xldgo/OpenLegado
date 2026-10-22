import 'package:flutter_legado/src/domain/contracts/bookmark_export_service.dart';
import 'package:flutter_legado/src/domain/models/bookmark_export_document.dart';
import 'package:flutter_legado/src/models/misc.dart';
import 'package:flutter_legado/src/platform/files/bookmark_document_saver.dart';

class RecordingBookmarkExporter implements BookmarkExportService {
  static const document = BookmarkExportDocument(
    fileName: 'bookmark-demo.md',
    mimeType: 'text/markdown',
    content: '原生文档\n😀',
  );
  final requests =
      <
        ({
          String name,
          String author,
          List<Bookmark> bookmarks,
          BookmarkExportFormat format,
        })
      >[];
  Object? error;
  @override
  Future<BookmarkExportDocument> buildDocument({
    required String bookName,
    required String bookAuthor,
    required List<Bookmark> bookmarks,
    required BookmarkExportFormat format,
  }) async {
    requests.add((
      name: bookName,
      author: bookAuthor,
      bookmarks: bookmarks,
      format: format,
    ));
    if (error case final error?) throw error;
    return document;
  }
}

class RecordingBookmarkSaver implements BookmarkDocumentSaver {
  BookmarkExportDocument? document;
  String? initialDirectory;
  int calls = 0;
  String? result;
  Object? error;
  @override
  Future<String?> save(
    BookmarkExportDocument document, {
    String? initialDirectory,
  }) async {
    calls++;
    this.document = document;
    this.initialDirectory = initialDirectory;
    if (error case final error?) throw error;
    return result;
  }
}
