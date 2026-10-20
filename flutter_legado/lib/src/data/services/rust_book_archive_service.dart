import '../bridge/rust_errors.dart';
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
    await rustFuture(
      () => bridge.archiveImportZip(zipPath: zipPath, outputDir: outputDir),
      operation: 'archiveImportZip',
    ),
    'archiveImportZip',
  );
  @override
  Future<List<String>> archiveImportRar({
    required String rarPath,
    required String outputDir,
    String? password,
  }) async => archiveFromDto(
    await rustFuture(
      () => bridge.archiveImportRar(
        rarPath: rarPath,
        outputDir: outputDir,
        password: password,
      ),
      operation: 'archiveImportRar',
    ),
    'archiveImportRar',
  );
  @override
  Future<List<String>> archiveListZipFiles({required String zipPath}) async =>
      rustFuture(
        () => bridge.archiveListZipFiles(zipPath: zipPath),
        operation: 'archiveListZipFiles',
      );
  @override
  Future<List<String>> archiveListRarFiles({
    required String rarPath,
    String? password,
  }) async => rustFuture(
    () => bridge.archiveListRarFiles(rarPath: rarPath, password: password),
    operation: 'archiveListRarFiles',
  );
  @override
  Future<EncodingDetection> archiveDetectEncoding({
    required String filePath,
  }) async {
    final result = await rustFuture(
      () => bridge.archiveDetectEncoding(filePath: filePath),
      operation: 'archiveDetectEncoding',
    );
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
    final result = await rustFuture(
      () => bridge.archiveConvertEncoding(
        filePath: filePath,
        fromEncoding: fromEncoding,
        toEncoding: toEncoding,
      ),
      operation: 'archiveConvertEncoding',
    );
    requireFileSuccess(result.success, result.error, 'archiveConvertEncoding');
    final path = result.outputPath;
    if (path == null) throw const FormatException('转换成功但缺少输出路径');
    return path;
  }

  @override
  Future<bool> archiveIsArchive({required String filePath}) => rustFuture(
    () => bridge.archiveIsArchive(filePath: filePath),
    operation: 'archiveIsArchive',
  );
}
