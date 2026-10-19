import 'package:material_ui/material_ui.dart';

import '../../features/privacy/privacy_gate.dart';
import '../../widgets/reader/book_reader_route.dart';
import '../../widgets/reader/read_aloud_player_transition.dart';
import 'route_names.dart';

/// Page只适配Navigator归属，继续使用已有转场及资源生命周期。— Codex + UI
class AppRoutePage extends Page<dynamic> {
  const AppRoutePage({
    required super.key,
    required super.name,
    super.arguments,
    required this.builder,
  });
  final WidgetBuilder builder;

  @override
  Route<dynamic> createRoute(BuildContext context) {
    if (name == AppRoutes.readAloudPlayer) {
      return ReadAloudPlayerRoute(
        settings: this,
        anchor: arguments is ReadAloudCapsuleAnchor
            ? arguments as ReadAloudCapsuleAnchor
            : null,
      );
    }
    if (name == AppRoutes.changeSource) {
      return ChangeSourceSheetRoute(settings: this, builder: builder);
    }
    Widget guarded(BuildContext context) => PrivacyAppGate(
      child: name == AppRoutes.bookGroups || name == AppRoutes.bookshelfManage
          ? PrivacyVerificationGate(builder: builder)
          : Builder(builder: builder),
    );
    if (name == AppRoutes.reader) {
      return BookReaderRoute<dynamic>(settings: this, builder: guarded);
    }
    return MaterialPageRoute<dynamic>(settings: this, builder: guarded);
  }
}

/// [A2 形态对齐 | full-stack-engineer + UI] 换源底部弹层路由：
/// - 非不透明（opaque: false）+ black54 屏障：前页保持可见并被半透明遮罩压暗
///   （Material 3 模态浮层遮罩规范值）
/// - 内容自底部上滑入场（bottom sheet 滑入/滑出，easeOutCubic/easeInCubic）
/// - 关闭语义对齐原版 DialogFragment dismiss：点遮罩 / 下滑面板 / 系统返回键
///   均 pop 本路由；路由结果回传新 bookUrl（调用方 is String 判定不变）
class ChangeSourceSheetRoute extends PopupRoute<dynamic> {
  ChangeSourceSheetRoute({required this.builder, required super.settings});

  final WidgetBuilder builder;
  CurvedAnimation? _slideAnimation;

  // 点遮罩关闭继续由换源面板自己的全屏命中层处理。
  @override
  bool get barrierDismissible => false;
  @override
  Color get barrierColor => Colors.black54;
  @override
  String? get barrierLabel => null;
  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);
  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 250);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => builder(context);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // 曲线随路由存活，避免每个动画帧重新注册监听。
    final curved = _slideAnimation ??= CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(curved),
      child: child,
    );
  }

  @override
  void dispose() {
    _slideAnimation?.dispose();
    super.dispose();
  }
}
