// rust_api.dart 的分域 part 文件（体检 §三.16 超长文件拆分，方法原样搬移）。
// 本文件承载 RustApiContentExt mixin：音频播放模式 / 压缩包导入。
// RustApi 经 with 组合各 mixin（成员合集实现 BookApi）；
// 解码辅助来自 RustApiDecode（on 约束），同一 library 内私有成员可直接访问。
part of 'rust_api.dart';

mixin RustApiContentExt on RustApiDecode implements BookApi {
  // ========== 压缩包导入 ==========

  /// 导入 ZIP 压缩包中的书籍文件
  ///
  /// 解压 ZIP 文件，提取其中的书籍文件到 [outputDir]。
  /// 返回 ArchiveImportResult JSON 解析后的 Map。
  @override
  Future<Map<String, dynamic>> archiveImportZip({
    required String zipPath,
    required String outputDir,
  }) async {
    final json = await bridge.archiveImportZip(
      zipPath: zipPath,
      outputDir: outputDir,
    );
    return _decodeMap(json, 'bookApi');
  }

  /// 导入 RAR 压缩包中的书籍文件（支持加密）
  ///
  /// 解压 RAR 文件，提取其中的书籍文件到 [outputDir]。
  /// [password] 为可选密码，用于加密 RAR 文件。
  @override
  Future<Map<String, dynamic>> archiveImportRar({
    required String rarPath,
    required String outputDir,
    String? password,
  }) async {
    final json = await bridge.archiveImportRar(
      rarPath: rarPath,
      outputDir: outputDir,
      password: password,
    );
    return _decodeMap(json, 'bookApi');
  }

  /// 列出 ZIP 压缩包中的书籍文件名（不解压）
  ///
  /// 返回压缩包内符合书籍格式的文件名列表。
  @override
  Future<List<String>> archiveListZipFiles({required String zipPath}) async {
    final json = await bridge.archiveListZipFiles(zipPath: zipPath);
    final list = _decodeList(json, 'bookApi');
    return list.map((e) => e.toString()).toList();
  }

  /// 列出 RAR 压缩包中的书籍文件名（不解压）
  ///
  /// [password] 为可选密码，用于加密 RAR 文件。
  @override
  Future<List<String>> archiveListRarFiles({
    required String rarPath,
    String? password,
  }) async {
    final json = await bridge.archiveListRarFiles(
      rarPath: rarPath,
      password: password,
    );
    final list = _decodeList(json, 'bookApi');
    return list.map((e) => e.toString()).toList();
  }

  /// 检测 TXT 文件编码
  ///
  /// 返回 EncodingResult JSON 解析后的 Map，包含：
  /// - encoding: 编码名称
  /// - has_bom: 是否通过 BOM 确定
  /// - confidence: 置信度（high/medium/low）
  @override
  Future<Map<String, dynamic>> archiveDetectEncoding({
    required String filePath,
  }) async {
    final json = await bridge.archiveDetectEncoding(filePath: filePath);
    return _decodeMap(json, 'bookApi');
  }

  /// 转换 TXT 文件编码
  ///
  /// 将文件从 [fromEncoding] 转换为 [toEncoding]，输出为新文件。
  /// 返回 ConvertResult JSON 解析后的 Map。
  @override
  Future<Map<String, dynamic>> archiveConvertEncoding({
    required String filePath,
    required String fromEncoding,
    required String toEncoding,
  }) async {
    final json = await bridge.archiveConvertEncoding(
      filePath: filePath,
      fromEncoding: fromEncoding,
      toEncoding: toEncoding,
    );
    return _decodeMap(json, 'bookApi');
  }

  /// 判断文件是否为压缩包格式
  ///
  /// 支持 .zip / .rar / .7z 等格式判断。
  @override
  Future<bool> archiveIsArchive({required String filePath}) =>
      bridge.archiveIsArchive(filePath: filePath);
}
