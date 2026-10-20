import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../domain/models/ui_settings.dart';
import '../providers/ui_settings/ui_settings_notifier.dart'
    show uiSettingsProvider;

/// 通用组件按实际用途订阅设置，不接触持久化或全局镜像。
enum UiSettingsAspect { topBar, details, dividers, readerTheme }

class UiSettingsScope extends InheritedModel<UiSettingsAspect> {
  const UiSettingsScope({
    super.key,
    required this.settings,
    required super.child,
  });

  final UiSettings settings;

  /// 独立组件预览或未装配应用宿主的测试使用不可变默认值。
  static UiSettings of(BuildContext context, UiSettingsAspect aspect) =>
      InheritedModel.inheritFrom<UiSettingsScope>(
        context,
        aspect: aspect,
      )?.settings ??
      const UiSettings();

  static Object _values(UiSettings ui, UiSettingsAspect aspect) =>
      switch (aspect) {
        UiSettingsAspect.topBar => (
          ui.topBarButtonStyle,
          ui.mergeTopBarActions,
          ui.useFlexibleTopAppBar,
          ui.topBarBackgroundOpacity,
          ui.enableBlur,
          ui.topBarBlurSigma,
          ui.topBarBlurTintOpacity,
        ),
        UiSettingsAspect.details => (
          ui.bookInfoDefaultCoverBackground,
          ui.bookInfoNetworkCoverBackground,
          ui.enableBlur,
        ),
        UiSettingsAspect.dividers => ui.enableItemDivider,
        UiSettingsAspect.readerTheme => (ui.themeStyle, ui.themeContrastLevel),
      };

  @override
  bool updateShouldNotify(UiSettingsScope oldWidget) =>
      !identical(settings, oldWidget.settings);

  @override
  bool updateShouldNotifyDependent(
    UiSettingsScope oldWidget,
    Set<UiSettingsAspect> dependencies,
  ) => dependencies.any(
    (aspect) =>
        _values(settings, aspect) != _values(oldWidget.settings, aspect),
  );
}

/// 只转发 Provider 当前快照；没有第二份可写状态或同步监听通道。
class UiSettingsHost extends ConsumerWidget {
  const UiSettingsHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      UiSettingsScope(settings: ref.watch(uiSettingsProvider), child: child);
}
