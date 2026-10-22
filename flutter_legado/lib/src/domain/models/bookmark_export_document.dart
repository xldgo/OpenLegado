/// 书签导出的固定格式与原生返回文档，不含平台路径。— Codex + Bridge
enum BookmarkExportFormat { json, markdown }

final class BookmarkExportDocument {
  const BookmarkExportDocument({
    required this.fileName,
    required this.mimeType,
    required this.content,
  });
  final String fileName;
  final String mimeType;
  final String content;
}
