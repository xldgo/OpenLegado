import 'package:material_ui/material_ui.dart';

class BookVariableDialog extends StatefulWidget {
  final String title;

  /// 说明文案（对齐原版 VariableDialog 的 comment 展示）
  final String comment;

  /// 输入框预填文本
  final String initialText;

  const BookVariableDialog({
    super.key,
    required this.title,
    required this.comment,
    required this.initialText,
  });

  @override
  State<BookVariableDialog> createState() => BookVariableDialogState();
}

class BookVariableDialogState extends State<BookVariableDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialText,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.comment,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              minLines: 3,
              maxLines: null,
              decoration: const InputDecoration(labelText: 'variable'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            // 先取值再 pop（controller 随子树卸载后不可再读）
            final value = _controller.text;
            Navigator.pop(context, value);
          },
          child: const Text('确定'),
        ),
      ],
    );
  }
}
