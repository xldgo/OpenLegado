import '../../data/services/app_settings_service.dart';
import '../../data/settings/config_settings_storage.dart';
import '../../data/settings/shared_preferences_settings_storage.dart';
import '../../domain/models/app_settings_snapshot.dart';

/// 启动与 Provider 共用装配；配置回调在需要访问 Rust 时才执行。— Codex + UI
AppSettingsService createAppSettingsService({
  Future<String?> Function(String)? readConfig,
  Future<void> Function(String, String)? writeConfig,
}) => AppSettingsService(
  storages: {
    SettingsStorageKind.preferences: SharedPreferencesSettingsStorage(),
    if (readConfig != null && writeConfig != null)
      SettingsStorageKind.rustConfig: ConfigSettingsStorage(
        read: readConfig,
        write: writeConfig,
      ),
  },
);
