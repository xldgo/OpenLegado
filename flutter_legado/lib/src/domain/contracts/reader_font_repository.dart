import '../models/reader_font.dart';

/// 结构化字体目录的唯一来源；选择字体由阅读偏好管理。— Codex + UI
abstract interface class ReaderFontRepository {
  List<ReaderFont> get current;
  Stream<List<ReaderFont>> watch();
  Future<List<ReaderFont>> load();
  Future<void> reload();
  Future<void> add(ReaderFont font);
}
