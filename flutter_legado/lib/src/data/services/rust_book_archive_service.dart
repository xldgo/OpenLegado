import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/book_archive_service.dart';
import '../../domain/models/book_content_result.dart';
import '../bridge/file_dto_mapping.dart';

/// 解包与编码处理沿用原执行链，稳定结果不经 JSON。— Codex + Bridge
final class RustBookArchiveService implements BookArchiveService {
  const RustBookArchiveService();
  @override
  Future<List<String>> archiveImportZip({
    required String zipPath,
    required String outputDir,
  }) async => archiveFromDto(
    await bridge.archiveImportZip(zipPath: zipPath, outputDir: outputDir),
    'archiveImportZip',
  );
  @override
  Future<List<String>> archiveImportRar({
    required String rarPath,
    required String outputDir,
    String? password,
  }) async => archiveFromDto(
    await bridge.archiveImportRar(
      rarPath: rarPath,
      outputDir: outputDir,
      password: password,
    ),
    'archiveImportRar',
  );
  @override
  Future<List<String>> archiveListZipFiles({required String zipPath}) async =>
      bridge.archiveListZipFiles(zipPath: zipPath);
  @override
  Future<List<String>> archiveListRarFiles({
    required String rarPath,
    String? password,
  }) async => bridge.archiveListRarFiles(rarPath: rarPath, password: password);
  @override
  Future<EncodingDetection> archiveDetectEncoding({
    required String filePath,
  }) async {
    final result = await bridge.archiveDetectEncoding(filePath: filePath);
    return EncodingDetection(
      encoding: result.encoding,
      hasBom: result.hasBom,
      confidence: result.confidence,
    );
  }

  @override
  Future<String> archiveConvertEncoding({
    required String filePath,
    required String fromEncoding,
    required String toEncoding,
  }) async {
    final result = await bridge.archiveConvertEncoding(
      filePath: filePath,
      fromEncoding: fromEncoding,
      toEncoding: toEncoding,
    );
    requireFileSuccess(result.success, result.error, 'archiveConvertEncoding');
    final path = result.outputPath;
    if (path == null) throw const FormatException('转换成功但缺少输出路径');
    return path;
  }

  @override
  Future<bool> archiveIsArchive({required String filePath}) =>
      bridge.archiveIsArchive(filePath: filePath);
}
