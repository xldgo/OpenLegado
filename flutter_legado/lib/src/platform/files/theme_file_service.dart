import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../../models/theme_document.dart';

/// 平台文件适配；null 表示用户取消，读写失败交由页面显示提示。
class ThemeFileService {
  Future<ThemeDocument?> importTheme() async {
    final result = await FilePicker.pickFile(
      dialogTitle: '导入主题',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final path = result?.path;
    if (path == null) return null;
    return ThemeDocument.fromJson(jsonDecode(await File(path).readAsString()));
  }

  Future<bool> exportTheme(ThemeDocument document) async {
    final path = await FilePicker.saveFile(
      dialogTitle: '导出主题',
      fileName: 'legado_theme.json',
      bytes: utf8.encode(
        const JsonEncoder.withIndent('  ').convert(document.toJson()),
      ),
      mimeType: 'application/json',
    );
    return path != null;
  }

  Future<String?> selectBackgroundImage() async {
    final result = await FilePicker.pickFile(
      type: FileType.image,
      dialogTitle: '选择背景图片',
      compressionQuality: Platform.isAndroid ? 30 : 0,
    );
    return result?.path;
  }
}
