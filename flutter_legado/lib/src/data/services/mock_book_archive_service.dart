import 'dart:io';

import '../../domain/contracts/book_archive_service.dart';
import '../../domain/models/book_content_result.dart';

/// 无真实文件IO的压缩包样例，字段与正式契约一致。— Codex + Bridge
final class MockBookArchiveService implements BookArchiveService {
  const MockBookArchiveService();
  @override
  Future<List<String>> archiveImportZip({
    required String zipPath,
    required String outputDir,
  }) async => [
    'book1.txt',
    'book2.epub',
  ].map((name) => '$outputDir${Platform.pathSeparator}$name').toList();
  @override
  Future<List<String>> archiveImportRar({
    required String rarPath,
    required String outputDir,
    String? password,
  }) async => ['$outputDir${Platform.pathSeparator}novel.txt'];
  @override
  Future<List<String>> archiveListZipFiles({required String zipPath}) async => [
    'book1.txt',
    'book2.epub',
    'readme.md',
  ];
  @override
  Future<List<String>> archiveListRarFiles({
    required String rarPath,
    String? password,
  }) async => ['novel.txt'];
  @override
  Future<EncodingDetection> archiveDetectEncoding({
    required String filePath,
  }) async => const EncodingDetection(
    encoding: 'UTF-8',
    hasBom: false,
    confidence: 'high',
  );
  @override
  Future<String> archiveConvertEncoding({
    required String filePath,
    required String fromEncoding,
    required String toEncoding,
  }) async => '$filePath.converted';
  @override
  Future<bool> archiveIsArchive({required String filePath}) async =>
      filePath.endsWith('.zip') ||
      filePath.endsWith('.rar') ||
      filePath.endsWith('.7z');
}
