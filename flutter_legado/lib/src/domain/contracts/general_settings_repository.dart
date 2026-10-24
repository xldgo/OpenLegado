import '../models/general_settings.dart';

/// 应用行为偏好的唯一访问入口；运行时服务动作由消费者执行。— Codex + UI
abstract interface class GeneralSettingsRepository {
  GeneralSettings get current;
  Stream<GeneralSettings> watch();
  Future<GeneralSettings> load();
  Future<void> reload();
  Future<void> update({
    String? defaultBookTreeUri,
    bool? showAddToShelfAlert,
    bool? showMangaUi,
    int? webPort,
    bool? defaultToRead,
    int? sourceEditMaxLines,
  });
}
