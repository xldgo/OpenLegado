import '../../constants/pref_keys.dart';
import '../../domain/contracts/ui_settings_repository.dart';
import '../../domain/models/app_settings_snapshot.dart';
import '../../domain/models/ui_settings.dart';
import '../../domain/models/ui_settings_values.dart';
import '../services/app_settings_service.dart';

/// 偏好键、默认值与读写限值统一解释，材质仅使用浮点比例和 sigma。— Codex + UI
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
    _address(PrefKeys.topBarBackgroundOpacity),
    _address(PrefKeys.labelVisibilityMode),
    _address(PrefKeys.bottomBarBackgroundOpacity),
    _address(PrefKeys.useFloatingBottomBar),
    _address(PrefKeys.showBottomView),
    _address(PrefKeys.tabletInterface),
    _address(PrefKeys.bookInfoFollowCoverColor),
    _address(PrefKeys.bookInfoNetworkCoverBackground),
    _address(PrefKeys.bookInfoDefaultCoverBackground),
    _address(PrefKeys.overrideBaseCardCornerRadius),
    _address(PrefKeys.baseCardCornerRadius),
    _address(PrefKeys.enableBlur),
    _address(PrefKeys.topBarBlurSigma),
    _address(PrefKeys.topBarBlurTintOpacity),
    _address(PrefKeys.bottomBarBlurSigma),
    _address(PrefKeys.bottomBarBlurTintOpacity),
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
    topBarBackgroundOpacity: UiSettingsValues.opacity(
      _read(
        snapshot,
        PrefKeys.topBarBackgroundOpacity,
        UiSettingsValues.topBarBackgroundOpacity,
      ),
      fallback: UiSettingsValues.topBarBackgroundOpacity,
    ),
    labelVisibilityMode: BottomBarLabelMode.fromName(
      _read(snapshot, PrefKeys.labelVisibilityMode, ''),
    ),
    bottomBarBackgroundOpacity: UiSettingsValues.opacity(
      _read(
        snapshot,
        PrefKeys.bottomBarBackgroundOpacity,
        UiSettingsValues.bottomBarBackgroundOpacity,
      ),
      fallback: UiSettingsValues.bottomBarBackgroundOpacity,
    ),
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
    baseCardCornerRadius: UiSettingsValues.cardRadius(
      _read(snapshot, PrefKeys.baseCardCornerRadius, 16),
    ),
    enableBlur: _read(snapshot, PrefKeys.enableBlur, false),
    topBarBlurSigma: UiSettingsValues.sigma(
      _read(
        snapshot,
        PrefKeys.topBarBlurSigma,
        UiSettingsValues.topBarBlurSigma,
      ),
      fallback: UiSettingsValues.topBarBlurSigma,
    ),
    topBarBlurTintOpacity: UiSettingsValues.opacity(
      _read(
        snapshot,
        PrefKeys.topBarBlurTintOpacity,
        UiSettingsValues.topBarBlurTintOpacity,
      ),
      fallback: UiSettingsValues.topBarBlurTintOpacity,
    ),
    bottomBarBlurSigma: UiSettingsValues.sigma(
      _read(
        snapshot,
        PrefKeys.bottomBarBlurSigma,
        UiSettingsValues.bottomBarBlurSigma,
      ),
      fallback: UiSettingsValues.bottomBarBlurSigma,
    ),
    bottomBarBlurTintOpacity: UiSettingsValues.opacity(
      _read(
        snapshot,
        PrefKeys.bottomBarBlurTintOpacity,
        UiSettingsValues.bottomBarBlurTintOpacity,
      ),
      fallback: UiSettingsValues.bottomBarBlurTintOpacity,
    ),
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
    double? topBarBackgroundOpacity,
    BottomBarLabelMode? labelVisibilityMode,
    double? bottomBarBackgroundOpacity,
    bool? useFloatingBottomBar,
    bool? showBottomView,
    TabletInterfaceMode? tabletInterface,
    bool? bookInfoFollowCoverColor,
    String? bookInfoNetworkCoverBackground,
    String? bookInfoDefaultCoverBackground,
    bool? overrideBaseCardCornerRadius,
    int? baseCardCornerRadius,
    bool? enableBlur,
    double? topBarBlurSigma,
    double? topBarBlurTintOpacity,
    double? bottomBarBlurSigma,
    double? bottomBarBlurTintOpacity,
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
    _address(
      PrefKeys.topBarBackgroundOpacity,
    ): ?(topBarBackgroundOpacity == null
        ? null
        : UiSettingsValues.opacity(
            topBarBackgroundOpacity,
            fallback: UiSettingsValues.topBarBackgroundOpacity,
          )),
    _address(PrefKeys.labelVisibilityMode): ?labelVisibilityMode?.name,
    _address(
      PrefKeys.bottomBarBackgroundOpacity,
    ): ?(bottomBarBackgroundOpacity == null
        ? null
        : UiSettingsValues.opacity(
            bottomBarBackgroundOpacity,
            fallback: UiSettingsValues.bottomBarBackgroundOpacity,
          )),
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
    _address(PrefKeys.baseCardCornerRadius): ?(baseCardCornerRadius == null
        ? null
        : UiSettingsValues.cardRadius(baseCardCornerRadius)),
    _address(PrefKeys.enableBlur): ?enableBlur,
    _address(PrefKeys.topBarBlurSigma): ?(topBarBlurSigma == null
        ? null
        : UiSettingsValues.sigma(
            topBarBlurSigma,
            fallback: UiSettingsValues.topBarBlurSigma,
          )),
    _address(PrefKeys.topBarBlurTintOpacity): ?(topBarBlurTintOpacity == null
        ? null
        : UiSettingsValues.opacity(
            topBarBlurTintOpacity,
            fallback: UiSettingsValues.topBarBlurTintOpacity,
          )),
    _address(PrefKeys.bottomBarBlurSigma): ?(bottomBarBlurSigma == null
        ? null
        : UiSettingsValues.sigma(
            bottomBarBlurSigma,
            fallback: UiSettingsValues.bottomBarBlurSigma,
          )),
    _address(
      PrefKeys.bottomBarBlurTintOpacity,
    ): ?(bottomBarBlurTintOpacity == null
        ? null
        : UiSettingsValues.opacity(
            bottomBarBlurTintOpacity,
            fallback: UiSettingsValues.bottomBarBlurTintOpacity,
          )),
    _address(PrefKeys.wallpaperColorFollow): ?wallpaperColorFollow,
    _address(PrefKeys.enableItemDivider): ?enableItemDivider,
    _address(PrefKeys.railExtended): ?railExtended,
    _address(PrefKeys.themeStyle): ?themeStyle,
    _address(PrefKeys.themeContrastLevel): ?themeContrastLevel,
    _address(PrefKeys.themeAmoled): ?themeAmoled,
  });
}
