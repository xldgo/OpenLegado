import 'package:flutter/painting.dart';

/// 独立于系统栏的四边缺口尺寸，统一转换为窗口逻辑像素。— Codex + UI
final class DisplayCutoutInsets {
  const DisplayCutoutInsets({required this.size, required this.padding});
  final Size size;
  final EdgeInsets padding;

  static DisplayCutoutInsets? fromPhysical(Object? raw, double pixelRatio) {
    if (raw is! Map || !pixelRatio.isFinite || pixelRatio <= 0) return null;
    double? value(String key) {
      final number = raw[key];
      return number is num && number.isFinite && number >= 0
          ? number.toDouble() / pixelRatio
          : null;
    }

    final width = value('width'), height = value('height');
    final left = value('left'), top = value('top');
    final right = value('right'), bottom = value('bottom');
    if (width == null ||
        height == null ||
        width <= 0 ||
        height <= 0 ||
        left == null ||
        top == null ||
        right == null ||
        bottom == null ||
        left + right > width ||
        top + bottom > height) {
      return null;
    }
    return DisplayCutoutInsets(
      size: Size(width, height),
      padding: EdgeInsets.fromLTRB(left, top, right, bottom),
    );
  }

  bool matches(Size viewport) =>
      (size.width - viewport.width).abs() <= 1 &&
      (size.height - viewport.height).abs() <= 1;

  @override
  bool operator ==(Object other) =>
      other is DisplayCutoutInsets &&
      size == other.size &&
      padding == other.padding;
  @override
  int get hashCode => Object.hash(size, padding);
}
