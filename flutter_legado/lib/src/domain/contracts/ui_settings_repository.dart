import '../models/ui_settings.dart';

/// 二十七项界面偏好的统一访问入口。— Codex + UI
abstract interface class UiSettingsRepository {
  UiSettings get current;
  Stream<UiSettings> watch();
  Future<UiSettings> load();
  Future<void> reload();
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
  });
}
