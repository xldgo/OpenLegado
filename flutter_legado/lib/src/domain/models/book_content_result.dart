import 'dart:typed_data';

/// 文件与导出操作的类型化结果。— Codex + Bridge
final class EncodingDetection {
  const EncodingDetection({
    required this.encoding,
    required this.hasBom,
    required this.confidence,
  });
  final String encoding;
  final bool hasBom;
  final String confidence;
}

final class BookExportOptions {
  const BookExportOptions({
    this.encoding,
    this.startChapter,
    this.endChapter,
    this.fileNameTemplate,
  });
  final String? encoding;
  final int? startChapter;
  final int? endChapter;
  final String? fileNameTemplate;
}

final class BookExportData {
  const BookExportData({
    required this.fileName,
    required this.bytes,
    required this.mimeType,
  });
  final String fileName;
  final Uint8List bytes;
  final String mimeType;
}

final class BookExportInfo {
  const BookExportInfo({required this.fileName, required this.chapterCount});
  final String fileName;
  final int chapterCount;
}
