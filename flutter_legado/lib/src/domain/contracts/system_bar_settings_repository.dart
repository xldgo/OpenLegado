import '../models/system_bar_settings.dart';

/// 系统栏偏好的读取、订阅和保存入口。— Codex + UI
abstract interface class SystemBarSettingsRepository {
  SystemBarSettings get current;
  Stream<SystemBarSettings> watch();
  Future<SystemBarSettings> load();
  Future<void> reload();
  Future<void> update({bool? transparentStatusBar, bool? immNavigationBar});
}
