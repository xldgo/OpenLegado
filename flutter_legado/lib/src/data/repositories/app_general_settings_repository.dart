import '../../constants/pref_keys.dart';
import '../../domain/contracts/general_settings_repository.dart';
import '../../domain/models/app_settings_snapshot.dart';
import '../../domain/models/general_settings.dart';
import '../services/app_settings_service.dart';

/// 普通偏好投影，存储与失败回退复用共享服务。— Codex + UI
final class AppGeneralSettingsRepository implements GeneralSettingsRepository {
  AppGeneralSettingsRepository(this._service);

  final AppSettingsService _service;
  bool _loaded = false;
  Future<GeneralSettings>? _loading;
  static SettingsAddress _address(String key) =>
      (storage: SettingsStorageKind.preferences, key: key);
  static final _addresses = {
    _address(PrefKeys.defaultBookTreeUri),
    _address(PrefKeys.showAddToShelfAlert),
    _address(PrefKeys.webPort),
    _address(PrefKeys.defaultToRead),
    _address(PrefKeys.sourceEditMaxLine),
  };

  T _read<T>(AppSettingsSnapshot snapshot, String key, T fallback) {
    final value = snapshot[_address(key)];
    return value is T ? value : fallback;
  }

  GeneralSettings _decode(AppSettingsSnapshot snapshot) => GeneralSettings(
    defaultBookTreeUri: _read(snapshot, PrefKeys.defaultBookTreeUri, ''),
    showAddToShelfAlert: _read(snapshot, PrefKeys.showAddToShelfAlert, true),
    webPort: _read(snapshot, PrefKeys.webPort, 1122),
    defaultToRead: _read(snapshot, PrefKeys.defaultToRead, false),
    sourceEditMaxLines: switch (snapshot[_address(
      PrefKeys.sourceEditMaxLine,
    )]) {
      final int lines when lines >= GeneralSettings.minimumSourceEditMaxLines =>
        lines,
      _ => 0,
    },
  );

  @override
  GeneralSettings get current => _decode(_service.current);
  @override
  Stream<GeneralSettings> watch() => _service.watch().map(_decode).distinct();
  @override
  Future<GeneralSettings> load() {
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
    String? defaultBookTreeUri,
    bool? showAddToShelfAlert,
    int? webPort,
    bool? defaultToRead,
    int? sourceEditMaxLines,
  }) {
    if (sourceEditMaxLines != null &&
        sourceEditMaxLines != 0 &&
        sourceEditMaxLines < GeneralSettings.minimumSourceEditMaxLines) {
      throw ArgumentError.value(
        sourceEditMaxLines,
        'sourceEditMaxLines',
        '至少10行或0表示不限',
      );
    }
    return _service.update({
      if (defaultBookTreeUri != null)
        _address(PrefKeys.defaultBookTreeUri): defaultBookTreeUri.isEmpty
            ? null
            : defaultBookTreeUri,
      _address(PrefKeys.showAddToShelfAlert): ?showAddToShelfAlert,
      _address(PrefKeys.webPort): ?webPort,
      _address(PrefKeys.defaultToRead): ?defaultToRead,
      _address(PrefKeys.sourceEditMaxLine): ?sourceEditMaxLines,
    });
  }
}
