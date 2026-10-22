import 'package:material_ui/material_ui.dart';

/// 页面提示共用入口；默认排队，替换旧提示须由调用方明确选择。— Codex + UI
void showAppSnackBar(
  BuildContext context,
  String message, {
  bool replaceCurrent = false,
  SnackBarAction? action,
  Duration duration = const Duration(seconds: 4),
}) {
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  if (replaceCurrent) messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(content: Text(message), action: action, duration: duration),
  );
}
