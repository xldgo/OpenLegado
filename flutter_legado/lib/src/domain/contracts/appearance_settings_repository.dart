import '../models/appearance_settings.dart';

/// 外观普通偏好的唯一访问入口。— Codex + UI
abstract interface class AppearanceSettingsRepository {
  AppearanceSettings get current;
  Stream<AppearanceSettings> watch();
  Future<AppearanceSettings> load();
  Future<void> reload();
  Future<void> update(
    AppearanceSettings Function(AppearanceSettings) transform,
  );
  Future<void> settled();
}
