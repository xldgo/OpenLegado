import 'dart:convert';
import 'dart:io';

/// UTF-8 书源文件读取，缺失与读取失败保持不同结果。— Codex + UI
Future<String?> readSourceImportFile(String path) async {
  final file = File(path);
  if (!await file.exists()) return null;
  return file.readAsString(encoding: utf8);
}
