import 'package:material_ui/material_ui.dart';

import '../../../../l10n/app_localization.dart';

/// 控制器随编辑器离场而释放，关闭动画期间输入框仍可访问它。
class ReaderContentEditDialog extends StatefulWidget {
  const ReaderContentEditDialog({
    super.key,
    required this.chapterTitle,
    required this.content,
  });

  final String chapterTitle;
  final String content;

  @override
  State<ReaderContentEditDialog> createState() =>
      _ReaderContentEditDialogState();
}

class _ReaderContentEditDialogState extends State<ReaderContentEditDialog> {
  late final _controller = TextEditingController(text: widget.content);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.chapterTitle.isEmpty
          ? context.l10n.editSourceContent
          : '编辑：${widget.chapterTitle}',
    ),
    content: SizedBox(
      width: double.maxFinite,
      child: TextField(
        controller: _controller,
        maxLines: null,
        minLines: 8,
        decoration: const InputDecoration(labelText: '章节正文'),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text),
        child: Text(context.l10n.save),
      ),
    ],
  );
}
