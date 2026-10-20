import 'dart:typed_data';

import '../models/reader_font.dart';

/// 共享字体资产能力，不负责界面或阅读字体偏好。— Codex + UI
abstract interface class FontCatalog {
  Future<({List<ReaderFont> fonts, List<String> missing})> loadAvailable();
  Future<String?> loadFamily(String family);
  Future<ReaderFont> importFont(String name, Uint8List bytes);
}
