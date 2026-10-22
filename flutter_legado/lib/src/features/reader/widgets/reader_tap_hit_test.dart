import 'dart:ui';

import '../../../domain/models/reader_interaction_settings.dart';

/// 按实际正文九宫格命中，边缘防误触规则沿用原实现。— Codex + UI
TapAction readerTapActionForPosition(
  ReaderInteractionSettings settings,
  Offset position,
  Size size,
) {
  if (!size.width.isFinite ||
      !size.height.isFinite ||
      size.width <= 0 ||
      size.height <= 0 ||
      !position.dx.isFinite ||
      !position.dy.isFinite ||
      position.dx < 0 ||
      position.dy < 0 ||
      position.dx >= size.width ||
      position.dy >= size.height) {
    return TapAction.none;
  }
  final deadZone = settings.pageTouchClick.toDouble().clamp(
    0.0,
    (size.width / 2 - 1).clamp(0.0, double.infinity),
  );
  if (position.dx < deadZone || position.dx > size.width - deadZone) {
    return TapAction.none;
  }
  final column = (position.dx / size.width * 3).floor().clamp(0, 2);
  final row = (position.dy / size.height * 3).floor().clamp(0, 2);
  return settings.tapActions[row * 3 + column];
}
