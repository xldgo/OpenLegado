import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/book_archive_service.dart';
import '../../domain/models/book_content_result.dart';
import '../bridge/book_content_decode.dart';
import '../bridge/rust_json_decode.dart';

/// 解包、编码识别及转换使用既有Rust实现。— Codex + Bridge
final class RustBookArchiveService implements BookArchiveService {
  const RustBookArchiveService();
  @override
  Future<List<String>> archiveImportZip({
    required String zipPath,
    required String outputDir,
  }) async => contentStrings(
    successfulContent(
      await bridge.archiveImportZip(zipPath: zipPath, outputDir: outputDir),
      'archiveImportZip',
    )['extracted_files'],
  );
  @override
  Future<List<String>> archiveImportRar({
    required String rarPath,
    required String outputDir,
    String? password,
  }) async => contentStrings(
    successfulContent(
      await bridge.archiveImportRar(
        rarPath: rarPath,
        outputDir: outputDir,
        password: password,
      ),
      'archiveImportRar',
    )['extracted_files'],
  );
  @override
  Future<List<String>> archiveListZipFiles({required String zipPath}) async =>
      contentStrings(
        decodeRustJsonList(
          await bridge.archiveListZipFiles(zipPath: zipPath),
          'archiveListZipFiles',
        ),
      );
  @override
  Future<List<String>> archiveListRarFiles({
    required String rarPath,
    String? password,
  }) async => contentStrings(
    decodeRustJsonList(
      await bridge.archiveListRarFiles(rarPath: rarPath, password: password),
      'archiveListRarFiles',
    ),
  );
  @override
  Future<EncodingDetection> archiveDetectEncoding({
    required String filePath,
  }) async {
    final map = decodeRustJsonMap(
      await bridge.archiveDetectEncoding(filePath: filePath),
      'archiveDetectEncoding',
    );
    if (map['has_bom'] is! bool) throw const FormatException('编码检测缺少BOM标记');
    return EncodingDetection(
      encoding: contentString(map, 'encoding'),
      hasBom: map['has_bom'] as bool,
      confidence: contentString(map, 'confidence'),
    );
  }

  @override
  Future<String> archiveConvertEncoding({
    required String filePath,
    required String fromEncoding,
    required String toEncoding,
  }) async => contentString(
    successfulContent(
      await bridge.archiveConvertEncoding(
        filePath: filePath,
        fromEncoding: fromEncoding,
        toEncoding: toEncoding,
      ),
      'archiveConvertEncoding',
    ),
    'output_path',
  );
  @override
  Future<bool> archiveIsArchive({required String filePath}) =>
      bridge.archiveIsArchive(filePath: filePath);
}
