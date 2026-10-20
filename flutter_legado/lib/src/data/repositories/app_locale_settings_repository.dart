import '../../domain/contracts/locale_settings_repository.dart';
import '../../domain/models/locale_settings.dart';
import '../../domain/models/app_settings_snapshot.dart';
import '../services/app_settings_service.dart';

/// 保留原偏好编码，委托同一共享设置服务。— Codex + UI
final class AppLocaleSettingsRepository implements LocaleSettingsRepository {
  AppLocaleSettingsRepository(
    this._service, {
    required Iterable<String> supportedLanguages,
  }) : _supportedLanguages = Set.unmodifiable(supportedLanguages);
  final Set<String> _supportedLanguages;
  String _normalize(String value) {
    final language = value.replaceAll('_', '-').split('-').first;
    return _supportedLanguages.contains(language) ? language : 'system';
  }

  final AppSettingsService _service;
  bool _loaded = false;
  Future<LocaleSettings>? _loading;
  static SettingsAddress _address(String key) =>
      (storage: SettingsStorageKind.preferences, key: key);
  static final _addresses = {_address('app_locale')};

  T _read<T>(AppSettingsSnapshot snapshot, String key, T fallback) {
    final value = snapshot[_address(key)];
    return value is T ? value : fallback;
  }

  LocaleSettings _decode(AppSettingsSnapshot snapshot) => LocaleSettings(
    locale: _normalize(_read(snapshot, 'app_locale', 'system')),
  );
  @override
  LocaleSettings get current => _decode(_service.current);
  @override
  Stream<LocaleSettings> watch() => _service.watch().map(_decode).distinct();
  @override
  Future<LocaleSettings> load() {
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
  Future<void> update({String? locale}) => _service.update({
    _address('app_locale'): ?(locale == null ? null : _normalize(locale)),
  });
}
