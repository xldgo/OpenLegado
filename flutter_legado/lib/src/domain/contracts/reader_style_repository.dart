import '../models/reader_style.dart';

/// 结构化阅读样式的唯一访问入口，普通操作偏好仍由阅读设置仓储拥有。— Codex + UI
abstract interface class ReaderStyleRepository {
  ReaderStyles get current;
  Stream<ReaderStyles> watch();
  Future<ReaderStyles> load();
  Future<void> reload();
  Future<void> select(String id);
  Future<void> setShareLayout(bool enabled);
  Future<String> createFromTemplate(String id, String name);
  Future<void> restorePreset(String presetId);
  Future<void> updateColors({
    required bool isNight,
    required ReaderColors Function(ReaderColors colors) update,
  });
}
