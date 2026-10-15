import '../../constants/pref_keys.dart';
import '../../domain/contracts/ui_settings_repository.dart';
import '../../domain/models/app_settings_snapshot.dart';
import '../../domain/models/ui_settings.dart';
import '../services/app_settings_service.dart';

/// 原键、默认值和保存限值统一在数据层解释。— Codex + UI
final class AppUiSettingsRepository implements UiSettingsRepository {
  AppUiSettingsRepository(this._service);
  final AppSettingsService _service;
  bool _loaded = false;
  Future<UiSettings>? _loading;
  static SettingsAddress _address(String key) =>
      (storage: SettingsStorageKind.preferences, key: key);
  static final _addresses = {
    _address(PrefKeys.topBarButtonStyle),
    _address(PrefKeys.mergeTopBarActions),
    _address(PrefKeys.useFlexibleTopAppBar),
    _address(PrefKeys.topBarOpacity),
    _address(PrefKeys.labelVisibilityMode),
    _address(PrefKeys.bottomBarOpacity),
    _address(PrefKeys.useFloatingBottomBar),
    _address(PrefKeys.showBottomView),
    _address(PrefKeys.tabletInterface),
    _address(PrefKeys.bookInfoFollowCoverColor),
    _address(PrefKeys.bookInfoNetworkCoverBackground),
    _address(PrefKeys.bookInfoDefaultCoverBackground),
    _address(PrefKeys.overrideBaseCardCornerRadius),
    _address(PrefKeys.baseCardCornerRadius),
    _address(PrefKeys.enableBlur),
    _address(PrefKeys.topBarBlurRadius),
    _address(PrefKeys.topBarBlurAlpha),
    _address(PrefKeys.bottomBarBlurRadius),
    _address(PrefKeys.bottomBarBlurAlpha),
    _address(PrefKeys.wallpaperColorFollow),
    _address(PrefKeys.enableItemDivider),
    _address(PrefKeys.railExtended),
    _address(PrefKeys.themeStyle),
    _address(PrefKeys.themeContrastLevel),
    _address(PrefKeys.themeAmoled),
  };

  T _read<T>(AppSettingsSnapshot snapshot, String key, T fallback) {
    final value = snapshot[_address(key)];
    return value is T ? value : fallback;
  }

  UiSettings _decode(AppSettingsSnapshot snapshot) => UiSettings(
    topBarButtonStyle: TopBarButtonStyle.fromName(
      _read(snapshot, PrefKeys.topBarButtonStyle, ''),
    ),
    mergeTopBarActions: _read(snapshot, PrefKeys.mergeTopBarActions, false),
    useFlexibleTopAppBar: _read(snapshot, PrefKeys.useFlexibleTopAppBar, true),
    topBarOpacity: _read(snapshot, PrefKeys.topBarOpacity, 100).clamp(0, 100),
    labelVisibilityMode: BottomBarLabelMode.fromName(
      _read(snapshot, PrefKeys.labelVisibilityMode, ''),
    ),
    bottomBarOpacity: _read(
      snapshot,
      PrefKeys.bottomBarOpacity,
      100,
    ).clamp(0, 100),
    useFloatingBottomBar: _read(snapshot, PrefKeys.useFloatingBottomBar, false),
    showBottomView: _read(snapshot, PrefKeys.showBottomView, true),
    tabletInterface: TabletInterfaceMode.fromName(
      _read(snapshot, PrefKeys.tabletInterface, ''),
    ),
    bookInfoFollowCoverColor: _read(
      snapshot,
      PrefKeys.bookInfoFollowCoverColor,
      true,
    ),
    bookInfoNetworkCoverBackground: _read(
      snapshot,
      PrefKeys.bookInfoNetworkCoverBackground,
      'on',
    ),
    bookInfoDefaultCoverBackground: _read(
      snapshot,
      PrefKeys.bookInfoDefaultCoverBackground,
      'on',
    ),
    overrideBaseCardCornerRadius: _read(
      snapshot,
      PrefKeys.overrideBaseCardCornerRadius,
      false,
    ),
    baseCardCornerRadius: _read(snapshot, PrefKeys.baseCardCornerRadius, 16),
    enableBlur: _read(snapshot, PrefKeys.enableBlur, false),
    topBarBlurRadius: _read(snapshot, PrefKeys.topBarBlurRadius, 24),
    topBarBlurAlpha: _read(snapshot, PrefKeys.topBarBlurAlpha, 73),
    bottomBarBlurRadius: _read(snapshot, PrefKeys.bottomBarBlurRadius, 8),
    bottomBarBlurAlpha: _read(snapshot, PrefKeys.bottomBarBlurAlpha, 40),
    wallpaperColorFollow: _read(snapshot, PrefKeys.wallpaperColorFollow, false),
    enableItemDivider: _read(snapshot, PrefKeys.enableItemDivider, false),
    railExtended: _read(snapshot, PrefKeys.railExtended, false),
    themeStyle: _read(snapshot, PrefKeys.themeStyle, 'none'),
    themeContrastLevel: _read(snapshot, PrefKeys.themeContrastLevel, '0.0'),
    themeAmoled: _read(snapshot, PrefKeys.themeAmoled, false),
  );
  @override
  UiSettings get current => _decode(_service.current);
  @override
  Stream<UiSettings> watch() => _service.watch().map(_decode).distinct();
  @override
  Future<UiSettings> load() {
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
    TopBarButtonStyle? topBarButtonStyle,
    bool? mergeTopBarActions,
    bool? useFlexibleTopAppBar,
    int? topBarOpacity,
    BottomBarLabelMode? labelVisibilityMode,
    int? bottomBarOpacity,
    bool? useFloatingBottomBar,
    bool? showBottomView,
    TabletInterfaceMode? tabletInterface,
    bool? bookInfoFollowCoverColor,
    String? bookInfoNetworkCoverBackground,
    String? bookInfoDefaultCoverBackground,
    bool? overrideBaseCardCornerRadius,
    int? baseCardCornerRadius,
    bool? enableBlur,
    int? topBarBlurRadius,
    int? topBarBlurAlpha,
    int? bottomBarBlurRadius,
    int? bottomBarBlurAlpha,
    bool? wallpaperColorFollow,
    bool? enableItemDivider,
    bool? railExtended,
    String? themeStyle,
    String? themeContrastLevel,
    bool? themeAmoled,
  }) => _service.update({
    _address(PrefKeys.topBarButtonStyle): ?topBarButtonStyle?.name,
    _address(PrefKeys.mergeTopBarActions): ?mergeTopBarActions,
    _address(PrefKeys.useFlexibleTopAppBar): ?useFlexibleTopAppBar,
    _address(PrefKeys.topBarOpacity): ?topBarOpacity?.clamp(0, 100),
    _address(PrefKeys.labelVisibilityMode): ?labelVisibilityMode?.name,
    _address(PrefKeys.bottomBarOpacity): ?bottomBarOpacity?.clamp(0, 100),
    _address(PrefKeys.useFloatingBottomBar): ?useFloatingBottomBar,
    _address(PrefKeys.showBottomView): ?showBottomView,
    _address(PrefKeys.tabletInterface): ?tabletInterface?.name,
    _address(PrefKeys.bookInfoFollowCoverColor): ?bookInfoFollowCoverColor,
    _address(PrefKeys.bookInfoNetworkCoverBackground):
        ?bookInfoNetworkCoverBackground,
    _address(PrefKeys.bookInfoDefaultCoverBackground):
        ?bookInfoDefaultCoverBackground,
    _address(PrefKeys.overrideBaseCardCornerRadius):
        ?overrideBaseCardCornerRadius,
    _address(PrefKeys.baseCardCornerRadius): ?baseCardCornerRadius?.clamp(
      4,
      28,
    ),
    _address(PrefKeys.enableBlur): ?enableBlur,
    _address(PrefKeys.topBarBlurRadius): ?topBarBlurRadius?.clamp(0, 48),
    _address(PrefKeys.topBarBlurAlpha): ?topBarBlurAlpha?.clamp(0, 255),
    _address(PrefKeys.bottomBarBlurRadius): ?bottomBarBlurRadius?.clamp(0, 48),
    _address(PrefKeys.bottomBarBlurAlpha): ?bottomBarBlurAlpha?.clamp(0, 255),
    _address(PrefKeys.wallpaperColorFollow): ?wallpaperColorFollow,
    _address(PrefKeys.enableItemDivider): ?enableItemDivider,
    _address(PrefKeys.railExtended): ?railExtended,
    _address(PrefKeys.themeStyle): ?themeStyle,
    _address(PrefKeys.themeContrastLevel): ?themeContrastLevel,
    _address(PrefKeys.themeAmoled): ?themeAmoled,
  });
}
