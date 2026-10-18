import '../models/ui_settings.dart';

/// 界面偏好的统一访问入口。— Codex + UI
abstract interface class UiSettingsRepository {
  UiSettings get current;
  Stream<UiSettings> watch();
  Future<UiSettings> load();
  Future<void> reload();
  Future<void> update({
    TopBarButtonStyle? topBarButtonStyle,
    bool? mergeTopBarActions,
    bool? useFlexibleTopAppBar,
    double? topBarBackgroundOpacity,
    BottomBarLabelMode? labelVisibilityMode,
    double? bottomBarBackgroundOpacity,
    bool? useFloatingBottomBar,
    bool? useFloatingBottomBarLiquidGlass,
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
  });
}
