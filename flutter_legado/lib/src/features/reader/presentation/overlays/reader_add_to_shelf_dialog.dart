import 'package:material_ui/material_ui.dart';

/// 阅读退出的入架确认框，只返回用户选择。— Codex + UI
Future<bool> showReaderAddToShelfDialog(BuildContext context, String bookName) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('放入书架'),
      content: Text('是否将《$bookName》放入书架？'),
      actionsAlignment: MainAxisAlignment.end,
      actionsPadding: const EdgeInsets.fromLTRB(12, 0, 16, 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('取消'),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('确认'),
        ),
      ],
    ),
  ).then((v) => v ?? false);
}
