import '../../domain/contracts/welcome_settings_repository.dart';
import '../../domain/models/welcome_settings.dart';
import '../../domain/models/app_settings_snapshot.dart';
import '../services/app_settings_service.dart';

/// 保留原偏好编码，委托同一共享设置服务。— Codex + UI
final class AppWelcomeSettingsRepository implements WelcomeSettingsRepository {
  AppWelcomeSettingsRepository(this._service);
  final AppSettingsService _service;
  bool _loaded = false;
  Future<WelcomeSettings>? _loading;
  static SettingsAddress _address(String key) =>
      (storage: SettingsStorageKind.preferences, key: key);
  static final _addresses = {
    _address('welcomeShowTime'),
    _address('customWelcome'),
    _address('welcomeImagePath'),
    _address('welcomeImagePathDark'),
    _address('welcomeShowText'),
    _address('welcomeShowIcon'),
    _address('welcomeShowTextDark'),
    _address('welcomeShowIconDark'),
    _address('defaultToRead'),
  };

  T _read<T>(AppSettingsSnapshot snapshot, String key, T fallback) {
    final value = snapshot[_address(key)];
    return value is T ? value : fallback;
  }

  WelcomeSettings _decode(AppSettingsSnapshot snapshot) => WelcomeSettings(
    showTime: _read(snapshot, 'welcomeShowTime', 500).clamp(0, 800),
    customWelcome: _read(snapshot, 'customWelcome', false),
    imageDay: _read(snapshot, 'welcomeImagePath', ''),
    imageNight: _read(snapshot, 'welcomeImagePathDark', ''),
    showText: _read(snapshot, 'welcomeShowText', true),
    showIcon: _read(snapshot, 'welcomeShowIcon', true),
    showTextDark: _read(snapshot, 'welcomeShowTextDark', true),
    showIconDark: _read(snapshot, 'welcomeShowIconDark', true),
    defaultToRead: _read(snapshot, 'defaultToRead', false),
  );
  @override
  WelcomeSettings get current => _decode(_service.current);
  @override
  Stream<WelcomeSettings> watch() => _service.watch().map(_decode).distinct();
  @override
  Future<WelcomeSettings> load() {
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
    int? showTime,
    bool? customWelcome,
    String? imageDay,
    String? imageNight,
    bool? showText,
    bool? showIcon,
    bool? showTextDark,
    bool? showIconDark,
    bool? defaultToRead,
  }) => _service.update({
    _address('welcomeShowTime'): ?(showTime?.clamp(0, 800)),
    _address('customWelcome'): ?(customWelcome),
    _address('welcomeImagePath'): ?(imageDay),
    _address('welcomeImagePathDark'): ?(imageNight),
    _address('welcomeShowText'): ?(showText),
    _address('welcomeShowIcon'): ?(showIcon),
    _address('welcomeShowTextDark'): ?(showTextDark),
    _address('welcomeShowIconDark'): ?(showIconDark),
    _address('defaultToRead'): ?(defaultToRead),
  });
}
