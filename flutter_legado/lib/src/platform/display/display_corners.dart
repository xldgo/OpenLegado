import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// 逻辑像素的窗口圆角；中心允许落在窗口外，分屏时仍按窗口坐标计算。— Codex + UI
class DisplayCorner {
  const DisplayCorner({required this.center, required this.radius});
  final Offset center;
  final double radius;

  @override
  bool operator ==(Object other) =>
      other is DisplayCorner &&
      other.center == center &&
      other.radius == radius;
  @override
  int get hashCode => Object.hash(center, radius);
}

class DisplayCorners {
  const DisplayCorners({required this.size, this.bottomLeft, this.bottomRight});
  final Size size;
  final DisplayCorner? bottomLeft, bottomRight;

  @override
  bool operator ==(Object other) =>
      other is DisplayCorners &&
      other.size == size &&
      other.bottomLeft == bottomLeft &&
      other.bottomRight == bottomRight;
  @override
  int get hashCode => Object.hash(size, bottomLeft, bottomRight);

  static DisplayCorners? fromPhysical(Object? raw, double pixelRatio) {
    if (raw is! Map || !pixelRatio.isFinite || pixelRatio <= 0) return null;
    double? number(Object? value) =>
        value is num && value.isFinite ? value.toDouble() / pixelRatio : null;
    final width = number(raw['width']), height = number(raw['height']);
    if (width == null || height == null || width <= 0 || height <= 0) {
      return null;
    }
    DisplayCorner? corner(Object? value) {
      if (value is! Map) return null;
      final radius = number(value['radius']);
      final x = number(value['x']), y = number(value['y']);
      if (radius == null || radius <= 0 || x == null || y == null) return null;
      return DisplayCorner(center: Offset(x, y), radius: radius);
    }

    return DisplayCorners(
      size: Size(width, height),
      bottomLeft: corner(raw['bottomLeft']),
      bottomRight: corner(raw['bottomRight']),
    );
  }

  /// 公开安全区不能反推出物理半径；移动端仅使用保守近似，桌面不补偿。
  static DisplayCorners fallback(
    Size size,
    EdgeInsets safe,
    TargetPlatform platform,
  ) {
    final mobile =
        platform == TargetPlatform.iOS || platform == TargetPlatform.android;
    final hint = math.max(safe.bottom, math.max(safe.left, safe.right));
    final radius = !mobile
        ? 0.0
        : math.min(size.shortestSide / 2, math.max(64.0, hint * 2));
    return DisplayCorners(
      size: size,
      bottomLeft: radius == 0
          ? null
          : DisplayCorner(
              center: Offset(radius, size.height - radius),
              radius: radius,
            ),
      bottomRight: radius == 0
          ? null
          : DisplayCorner(
              center: Offset(size.width - radius, size.height - radius),
              radius: radius,
            ),
    );
  }

  /// 返回已扣用户边距后的额外内收量；只处理文字带与底部圆角相交的部分。
  EdgeInsets extraInsets(Rect textBand) {
    double boundary(DisplayCorner corner, bool left) {
      final dy = textBand.bottom - corner.center.dy;
      if (dy <= 0) return left ? 0 : size.width;
      final vertical = math.min(corner.radius, dy);
      final dx = math.sqrt(
        math.max(0, corner.radius * corner.radius - vertical * vertical),
      );
      return corner.center.dx + (left ? -dx + 4 : dx - 4);
    }

    return EdgeInsets.only(
      left: bottomLeft == null
          ? 0
          : math.max(0, boundary(bottomLeft!, true) - textBand.left),
      right: bottomRight == null
          ? 0
          : math.max(0, textBand.right - boundary(bottomRight!, false)),
    );
  }
}
