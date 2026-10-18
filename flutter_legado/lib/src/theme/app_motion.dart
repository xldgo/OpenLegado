import 'package:flutter/widgets.dart';

/// 自定义动效共用系统偏好；标准组件继续使用自身的动画规则。— Codex + UI
abstract final class AppMotion {
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  static Duration duration(BuildContext context, Duration normal) =>
      reduced(context) ? Duration.zero : normal;
}
