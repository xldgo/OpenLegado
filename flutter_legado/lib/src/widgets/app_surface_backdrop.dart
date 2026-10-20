import 'dart:ui' show ImageFilter;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart'
    show
        BackdropFilterLayer,
        ClipRectLayer,
        LayerHandle,
        PaintingContext,
        RenderProxySliver,
        RenderObject;

import '../theme/app_surface_material.dart';

/// 仅在可见材质形状内模糊背景，留白和阴影由调用方放在外侧。— Codex + UI
class AppSurfaceBackdrop extends StatelessWidget {
  const AppSurfaceBackdrop({
    super.key,
    required this.material,
    required this.child,
    this.borderRadius,
  });

  final AppSurfaceMaterial material;
  final BorderRadius? borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!material.hasBlur) return child;
    final backdrop = BackdropFilter(
      filter: ImageFilter.blur(
        sigmaX: material.blurSigma,
        sigmaY: material.blurSigma,
      ),
      child: child,
    );
    return borderRadius == null
        ? ClipRect(child: backdrop)
        : ClipRRect(borderRadius: borderRadius!, child: backdrop);
  }
}

/// Sliver 对应的背景模糊，只包裹当前可见头部，不替换内建大标题布局。
class AppSliverSurfaceBackdrop extends SingleChildRenderObjectWidget {
  const AppSliverSurfaceBackdrop({
    super.key,
    required this.material,
    required super.child,
  });

  final AppSurfaceMaterial material;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSliverSurfaceBackdrop(material.blurSigma);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderObject renderObject,
  ) {
    (renderObject as _RenderSliverSurfaceBackdrop).sigma = material.blurSigma;
  }
}

class _RenderSliverSurfaceBackdrop extends RenderProxySliver {
  _RenderSliverSurfaceBackdrop(double sigma)
    : _sigma = sigma,
      _filter = _createFilter(sigma);

  static ImageFilter? _createFilter(double sigma) =>
      sigma > 0 ? ImageFilter.blur(sigmaX: sigma, sigmaY: sigma) : null;

  double _sigma;
  ImageFilter? _filter;
  final _filterLayer = LayerHandle<BackdropFilterLayer>();
  final _clipLayer = LayerHandle<ClipRectLayer>();

  set sigma(double value) {
    if (_sigma == value) return;
    final wasBlurred = _sigma > 0;
    _sigma = value;
    _filter = _createFilter(value);
    if (wasBlurred != (value > 0)) markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => child != null && _sigma > 0;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!geometry!.visible) return;
    if (_sigma <= 0) {
      _filterLayer.layer = null;
      _clipLayer.layer = null;
      super.paint(context, offset);
      return;
    }
    final filter = _filterLayer.layer ??= BackdropFilterLayer();
    filter.filter = _filter;
    _clipLayer.layer = context.pushClipRect(
      true,
      offset,
      paintBounds,
      (context, offset) => context.pushLayer(filter, super.paint, offset),
      oldLayer: _clipLayer.layer,
    );
  }

  @override
  void dispose() {
    _filterLayer.layer = null;
    _clipLayer.layer = null;
    super.dispose();
  }
}
