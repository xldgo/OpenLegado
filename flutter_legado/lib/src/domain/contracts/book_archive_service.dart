import '../models/book_content_result.dart';

/// 书籍压缩包与文件编码操作，解包失败抛出错误。— Codex + Bridge
abstract interface class BookArchiveService {
  Future<List<String>> archiveImportZip({
    required String zipPath,
    required String outputDir,
  });
  Future<List<String>> archiveImportRar({
    required String rarPath,
    required String outputDir,
    String? password,
  });
  Future<List<String>> archiveListZipFiles({required String zipPath});
  Future<List<String>> archiveListRarFiles({
    required String rarPath,
    String? password,
  });
  Future<EncodingDetection> archiveDetectEncoding({required String filePath});
  Future<String> archiveConvertEncoding({
    required String filePath,
    required String fromEncoding,
    required String toEncoding,
  });
  Future<bool> archiveIsArchive({required String filePath});
}
