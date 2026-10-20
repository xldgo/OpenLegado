import '../../bridge/file_dto.dart';
import '../../domain/models/book_content_result.dart';
import '../../domain/errors/app_exception.dart';

// 类型化文件结果仍拒绝成功标记与实际内容不一致的载荷。— Codex + Bridge
void requireFileSuccess(bool success, String? error, String operation) {
  if (!success) {
    throw AppException(error ?? '$operation失败', operation: operation);
  }
}

BookExportData bookExportFromDto(BookExportDto result) {
  requireFileSuccess(result.success, result.error, 'bookExport');
  final bytes = result.data;
  final name = result.fileName;
  final mime = result.mimeType;
  if (bytes == null || name == null || mime == null) {
    throw const FormatException('导出成功但缺少文件字段');
  }
  return BookExportData(fileName: name, bytes: bytes, mimeType: mime);
}

BookExportInfo bookExportInfoFromDto(BookExportDto result) {
  requireFileSuccess(result.success, result.error, 'bookExportInfo');
  final name = result.fileName;
  final count = result.chapterCount;
  if (name == null || count == null) {
    throw const FormatException('导出预览缺少章节数或文件名');
  }
  return BookExportInfo(fileName: name, chapterCount: count.toInt());
}

List<String> archiveFromDto(ArchiveImportDto result, String operation) {
  requireFileSuccess(result.success, result.error, operation);
  return result.extractedFiles;
}

Map<String, dynamic> webDavFileFromDto(WebDavFileDto file) => {
  'name': file.name,
  'path': file.path,
  'size': file.size.toInt(),
  'last_modified': file.lastModified,
  'etag': file.etag,
  'is_dir': file.isDir,
};
