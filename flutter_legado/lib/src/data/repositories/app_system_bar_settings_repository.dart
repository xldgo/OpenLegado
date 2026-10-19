import '../../constants/pref_keys.dart';
import '../../domain/contracts/system_bar_settings_repository.dart';
import '../../domain/models/app_settings_snapshot.dart';
import '../../domain/models/system_bar_settings.dart';
import '../services/app_settings_service.dart';

/// 沿用原偏好键，共享保存队列、快照与失败回退。— Codex + UI
final class AppSystemBarSettingsRepository
    implements SystemBarSettingsRepository {
  AppSystemBarSettingsRepository(this._service);

  final AppSettingsService _service;
  bool _loaded = false;
  Future<SystemBarSettings>? _loading;

  static SettingsAddress _address(String key) =>
      (storage: SettingsStorageKind.preferences, key: key);
  static final _addresses = {
    _address(PrefKeys.transparentStatusBar),
    _address(PrefKeys.immNavigationBar),
  };

  bool _read(AppSettingsSnapshot snapshot, String key, bool fallback) {
    final value = snapshot[_address(key)];
    return value is bool ? value : fallback;
  }

  SystemBarSettings _decode(AppSettingsSnapshot snapshot) => SystemBarSettings(
    transparentStatusBar: _read(snapshot, PrefKeys.transparentStatusBar, true),
    immNavigationBar: _read(snapshot, PrefKeys.immNavigationBar, true),
  );

  @override
  SystemBarSettings get current => _decode(_service.current);

  @override
  Stream<SystemBarSettings> watch() => _service.watch().map(_decode).distinct();

  @override
  Future<SystemBarSettings> load() {
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
  Future<void> update({bool? transparentStatusBar, bool? immNavigationBar}) =>
      _service.update({
        _address(PrefKeys.transparentStatusBar): ?transparentStatusBar,
        _address(PrefKeys.immNavigationBar): ?immNavigationBar,
      });
}
