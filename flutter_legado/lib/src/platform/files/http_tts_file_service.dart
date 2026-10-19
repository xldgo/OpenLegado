import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';

/// 取消选择返回 null/false，文件错误交给调用方展示。— Codex + UI
class HttpTtsFileService {
  Future<String?> read() async {
    final file = await FilePicker.pickFile(
      dialogTitle: '导入 HTTP TTS',
      type: FileType.custom,
      allowedExtensions: ['json', 'txt'],
    );
    if (file == null) return null;
    final path = file.path;
    if (path == null) throw const FileSystemException('无法读取所选文件');
    return File(path).readAsString(encoding: utf8);
  }

  Future<bool> write(String document) async =>
      await FilePicker.saveFile(
        dialogTitle: '导出 HTTP TTS',
        fileName: 'httpTTS.json',
        bytes: utf8.encode(document),
        mimeType: 'application/json',
      ) !=
      null;
}
