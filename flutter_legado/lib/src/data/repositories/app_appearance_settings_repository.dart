import '../../domain/contracts/appearance_settings_repository.dart';
import '../../domain/models/app_settings_snapshot.dart';
import '../../domain/models/appearance_settings.dart';
import '../services/app_settings_service.dart';

/// 只编码和投影共享快照，不另建外观状态或写队列。— Codex + UI
final class AppAppearanceSettingsRepository
    implements AppearanceSettingsRepository {
  AppAppearanceSettingsRepository(this._service);
  final AppSettingsService _service;
  bool _loaded = false;
  Future<AppearanceSettings>? _loading;

  static const _mode = (
    storage: SettingsStorageKind.preferences,
    key: 'app_theme_mode',
  );
  static const _scale = (
    storage: SettingsStorageKind.preferences,
    key: 'app_font_scale',
  );
  static const _palette = (
    storage: SettingsStorageKind.preferences,
    key: 'app_palette_id',
  );
  static const _icon = (
    storage: SettingsStorageKind.preferences,
    key: 'launcherIcon',
  );
  static const _font = (
    storage: SettingsStorageKind.preferences,
    key: 'app_font_family',
  );
  static const _addresses = {_mode, _scale, _palette, _icon, _font};

  AppearanceSettings _decode(AppSettingsSnapshot snapshot) =>
      AppearanceSettings(
        themeMode: switch (snapshot[_mode]) {
          'light' => AppThemeMode.light,
          'dark' => AppThemeMode.dark,
          _ => AppThemeMode.system,
        },
        // 沿用旧读取器的错误类型兜底，仅影响展示，不改写原存储。
        fontScaleRaw: switch (snapshot[_scale]) {
          int value => value,
          _ => 0,
        },
        paletteId: switch (snapshot[_palette]) {
          String value => value,
          _ => 'def',
        },
        launcherIcon: switch (snapshot[_icon]) {
          String value => value,
          _ => 'iconMain',
        },
        fontFamily: switch (snapshot[_font]) {
          String value => value,
          _ => '',
        },
      );

  Map<SettingsAddress, Object?> _encode(AppearanceSettings settings) => {
    _mode: settings.themeMode.name,
    _scale: settings.fontScaleRaw,
    _palette: settings.paletteId,
    _icon: settings.launcherIcon,
    _font: settings.fontFamily,
  };

  @override
  AppearanceSettings get current => _decode(_service.current);

  @override
  Stream<AppearanceSettings> watch() =>
      _service.watch().map(_decode).distinct();

  @override
  Future<AppearanceSettings> load() {
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
  Future<void> update(
    AppearanceSettings Function(AppearanceSettings) transform,
  ) {
    // 首次加载前不能用默认值判断差量，否则选择默认主题会丢失，或覆盖其他已存字段。
    if (!_loaded) return load().then((_) => _updateLoaded(transform));
    return _updateLoaded(transform);
  }

  Future<void> _updateLoaded(
    AppearanceSettings Function(AppearanceSettings) transform,
  ) {
    final before = _encode(current);
    final after = _encode(transform(current));
    return _service.update({
      for (final entry in after.entries)
        if (before[entry.key] != entry.value) entry.key: entry.value,
    });
  }

  @override
  Future<void> reload() async {
    await _service.reload(_addresses);
    _loaded = true;
  }

  @override
  Future<void> settled() => _service.settled();
}
