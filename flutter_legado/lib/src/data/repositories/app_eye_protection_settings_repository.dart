import '../../domain/contracts/eye_protection_settings_repository.dart';
import '../../domain/models/eye_protection_settings.dart';
import '../../domain/models/app_settings_snapshot.dart';
import '../services/app_settings_service.dart';

/// 保留原偏好编码，委托同一共享设置服务。— Codex + UI
final class AppEyeProtectionSettingsRepository
    implements EyeProtectionSettingsRepository {
  AppEyeProtectionSettingsRepository(this._service);
  final AppSettingsService _service;
  bool _loaded = false;
  Future<EyeProtectionSettings>? _loading;
  static SettingsAddress _address(String key) =>
      (storage: SettingsStorageKind.preferences, key: key);
  static final _addresses = {
    _address('eyeProtectionEnabled'),
    _address('colorTemperature'),
    _address('eyeProtectionAutoNight'),
    _address('eyeProtectionSchedule'),
    _address('eyeProtectionStartTime'),
    _address('eyeProtectionEndTime'),
  };

  T _read<T>(AppSettingsSnapshot snapshot, String key, T fallback) {
    final value = snapshot[_address(key)];
    return value is T ? value : fallback;
  }

  EyeProtectionSettings _decode(AppSettingsSnapshot snapshot) =>
      EyeProtectionSettings(
        enabled: _read(snapshot, 'eyeProtectionEnabled', false),
        intensity: _read(snapshot, 'colorTemperature', 50).clamp(0, 100),
        autoNight: _read(snapshot, 'eyeProtectionAutoNight', false),
        schedule: _read(snapshot, 'eyeProtectionSchedule', false),
        startTime: _read(snapshot, 'eyeProtectionStartTime', '22:00'),
        endTime: _read(snapshot, 'eyeProtectionEndTime', '07:00'),
      );
  @override
  EyeProtectionSettings get current => _decode(_service.current);
  @override
  Stream<EyeProtectionSettings> watch() =>
      _service.watch().map(_decode).distinct();
  @override
  Future<EyeProtectionSettings> load() {
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
    bool? enabled,
    int? intensity,
    bool? autoNight,
    bool? schedule,
    String? startTime,
    String? endTime,
  }) => _service.update({
    _address('eyeProtectionEnabled'): ?(enabled),
    _address('colorTemperature'): ?(intensity?.clamp(0, 100)),
    _address('eyeProtectionAutoNight'): ?(autoNight),
    _address('eyeProtectionSchedule'): ?(schedule),
    _address('eyeProtectionStartTime'): ?(startTime),
    _address('eyeProtectionEndTime'): ?(endTime),
  });
}
