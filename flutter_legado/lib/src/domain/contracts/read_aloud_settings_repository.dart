import '../models/read_aloud_settings.dart';

/// 朗读普通偏好的唯一访问入口；不暴露 config 键或 SharedPreferences。— Codex + UI
abstract interface class ReadAloudSettingsRepository {
  ReadAloudSettings get current;
  Stream<ReadAloudSettings> watch();
  Future<ReadAloudSettings> load();
  Future<void> reload();
  Future<void> update(ReadAloudSettings Function(ReadAloudSettings) transform);
  Future<void> settled();
}
