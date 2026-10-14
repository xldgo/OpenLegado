import '../../constants/pref_keys.dart';
import '../../domain/contracts/theme_colors_settings_repository.dart';
import '../../domain/models/app_settings_snapshot.dart';
import '../../domain/models/theme_colors_settings.dart';
import '../services/app_settings_service.dart';

/// 原颜色键与背景路径经共享快照读写，不另建缓存或队列。— Codex + UI
final class AppThemeColorsSettingsRepository
    implements ThemeColorsSettingsRepository {
  AppThemeColorsSettingsRepository(this._service);
  final AppSettingsService _service;
  bool _loaded = false;
  Future<ThemeColorsSettings>? _loading;

  static const _keys = {
    ThemeColorRole.primary: PrefKeys.cPrimary,
    ThemeColorRole.accent: PrefKeys.cAccent,
    ThemeColorRole.background: PrefKeys.cBackground,
    ThemeColorRole.bottomBackground: PrefKeys.cBBackground,
    ThemeColorRole.primaryNight: PrefKeys.cNPrimary,
    ThemeColorRole.accentNight: PrefKeys.cNAccent,
    ThemeColorRole.backgroundNight: PrefKeys.cNBackground,
    ThemeColorRole.bottomBackgroundNight: PrefKeys.cNBBackground,
  };
  static SettingsAddress _address(String key) =>
      (storage: SettingsStorageKind.preferences, key: key);
  static final _addresses = {
    for (final key in _keys.values) _address(key),
    _address(PrefKeys.bgImage),
    _address(PrefKeys.bgImageN),
  };

  ThemeColorsSettings _decode(AppSettingsSnapshot snapshot) {
    int? color(ThemeColorRole role) =>
        switch (snapshot[_address(_keys[role]!)]) {
          int value => value,
          _ => null,
        };
    String image(String key) => switch (snapshot[_address(key)]) {
      String value => value,
      _ => '',
    };
    return ThemeColorsSettings(
      primary: color(ThemeColorRole.primary),
      accent: color(ThemeColorRole.accent),
      background: color(ThemeColorRole.background),
      bottomBackground: color(ThemeColorRole.bottomBackground),
      primaryNight: color(ThemeColorRole.primaryNight),
      accentNight: color(ThemeColorRole.accentNight),
      backgroundNight: color(ThemeColorRole.backgroundNight),
      bottomBackgroundNight: color(ThemeColorRole.bottomBackgroundNight),
      bgImage: image(PrefKeys.bgImage),
      bgImageNight: image(PrefKeys.bgImageN),
    );
  }

  @override
  ThemeColorsSettings get current => _decode(_service.current);
  @override
  Stream<ThemeColorsSettings> watch() =>
      _service.watch().map(_decode).distinct();
  @override
  Future<ThemeColorsSettings> load() {
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
  Future<void> setColors(Map<ThemeColorRole, int?> colors) => _service.update({
    for (final entry in colors.entries)
      _address(_keys[entry.key]!): entry.value,
  });

  @override
  Future<void> setBgImage({String? day, String? night}) => _service.update({
    if (day != null) _address(PrefKeys.bgImage): day.isEmpty ? null : day,
    if (night != null)
      _address(PrefKeys.bgImageN): night.isEmpty ? null : night,
  });
}
