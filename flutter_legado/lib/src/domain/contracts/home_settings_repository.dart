import '../models/home_settings.dart';

/// 主界面三项偏好的唯一访问入口，更新只携带显式选择的字段。— Codex + UI
abstract interface class HomeSettingsRepository {
  HomeSettings get current;
  Stream<HomeSettings> watch();
  Future<HomeSettings> load();
  Future<void> reload();
  Future<void> update({
    bool? showDiscovery,
    bool? showRss,
    String? defaultHomePage,
  });
  Future<void> settled();
}
