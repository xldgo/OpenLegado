import '../../domain/contracts/backup_settings_repository.dart';
import '../../domain/models/app_settings_snapshot.dart';
import '../../domain/models/backup_settings.dart';
import '../services/app_settings_service.dart';

/// 保留备份原路径与进度开关键，不复制连接或凭据。— Codex + UI
final class AppBackupSettingsRepository implements BackupSettingsRepository {
  AppBackupSettingsRepository(this._service);

  final AppSettingsService _service;
  bool _loaded = false;
  Future<BackupSettings>? _loading;
  static const _path = (
    storage: SettingsStorageKind.preferences,
    key: 'app_backup_path',
  );
  static const _progress = (
    storage: SettingsStorageKind.preferences,
    key: 'sync_book_progress',
  );
  static const _autoSync = (
    storage: SettingsStorageKind.preferences,
    key: 'sync_auto',
  );
  static const _progressPlus = (
    storage: SettingsStorageKind.preferences,
    key: 'sync_book_progress_plus',
  );
  static const _cloud = (
    storage: SettingsStorageKind.preferences,
    key: 'backup_include_cloud_credentials',
  );
  static const _addresses = {
    _path,
    _progress,
    _autoSync,
    _progressPlus,
    _cloud,
  };

  BackupSettings _decode(AppSettingsSnapshot snapshot) => BackupSettings(
    includeCloudCredentials: snapshot[_cloud] == true,
    backupPath: snapshot[_path] is String ? snapshot[_path] as String : '',
    syncBookProgress: snapshot[_progress] is bool
        ? snapshot[_progress] as bool
        : true,
    autoSync: snapshot[_autoSync] is bool ? snapshot[_autoSync] as bool : false,
    syncBookProgressPlus: snapshot[_progressPlus] is bool
        ? snapshot[_progressPlus] as bool
        : false,
  );

  @override
  BackupSettings get current => _decode(_service.current);
  @override
  Stream<BackupSettings> watch() => _service.watch().map(_decode).distinct();
  @override
  Future<BackupSettings> load() {
    if (_loaded) return Future.value(current);
    return _loading ??= _service
        .load(_addresses)
        .then((_) {
          _loaded = true;
          return current;
        })
        .whenComplete(() => _loading = null);
  }

  @override
  Future<void> reload() async {
    await _service.reload(_addresses);
    _loaded = true;
  }

  @override
  Future<void> update({
    String? backupPath,
    bool? syncBookProgress,
    bool? includeCloudCredentials,
  }) => _service.update({
    if (backupPath != null) _path: backupPath.isEmpty ? null : backupPath,
    _progress: ?syncBookProgress,
    _cloud: ?includeCloudCredentials,
  });
}
