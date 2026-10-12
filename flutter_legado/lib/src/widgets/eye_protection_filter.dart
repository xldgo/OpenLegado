import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/ui_settings/eye_protection_notifier.dart';
import '../theme/eye_protection.dart';

/// 对齐上游 BaseComposeActivity：全局过滤一次，菜单和正文不再叠第二层。
class EyeProtectionFilter extends ConsumerStatefulWidget {
  const EyeProtectionFilter({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<EyeProtectionFilter> createState() =>
      _EyeProtectionFilterState();
}

class _EyeProtectionFilterState extends ConsumerState<EyeProtectionFilter>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(eyeProtectionProvider);
    if (settings.configured && settings.schedule) {
      _timer ??= Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _timer?.cancel();
      _timer = null;
    }
    final active =
        settings.intensity > 0 &&
        settings.isActiveAt(
          isDark: Theme.of(context).brightness == Brightness.dark,
          now: DateTime.now(),
        );
    return _OptionalColorFilter(
      filter: active
          ? ColorFilter.matrix(eyeProtectionMatrix(settings.intensity))
          : null,
      child: widget.child,
    );
  }
}

/// 关闭时不创建滤镜图层，开关切换也不卸载导航器和播放器子树。
class _OptionalColorFilter extends SingleChildRenderObjectWidget {
  const _OptionalColorFilter({required this.filter, required super.child});
  final ColorFilter? filter;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _FilterRenderObject(filter);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _FilterRenderObject renderObject,
  ) {
    renderObject.filter = filter;
  }
}

class _FilterRenderObject extends RenderProxyBox {
  _FilterRenderObject(this._filter);
  ColorFilter? _filter;

  set filter(ColorFilter? value) {
    if (_filter == value) return;
    final compositingChanged = (_filter == null) != (value == null);
    _filter = value;
    if (compositingChanged) markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => child != null && _filter != null;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_filter == null || child == null) {
      layer = null;
      super.paint(context, offset);
      return;
    }
    layer = context.pushColorFilter(
      offset,
      _filter!,
      super.paint,
      oldLayer: layer is ColorFilterLayer ? layer! as ColorFilterLayer : null,
    );
  }
}
