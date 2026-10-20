import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

/// 文件选择与读取由平台层处理；取消不改动设置。— Codex + UI
class AppFontPicker {
  Future<({String name, Uint8List bytes})?> pick() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['ttf', 'otf'],
    );
    if (file == null) return null;
    return (name: file.name, bytes: await file.readAsBytes());
  }
}
