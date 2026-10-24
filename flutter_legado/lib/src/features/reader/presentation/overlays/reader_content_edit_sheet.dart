import 'package:material_ui/material_ui.dart';

import '../../../../l10n/app_localization.dart';
import '../../../../widgets/app_settings_sheet.dart';

/// 控制器随编辑器离场而释放，关闭动画期间输入框仍可访问它。
class ReaderContentEditSheet extends StatefulWidget {
  const ReaderContentEditSheet({
    super.key,
    required this.chapterTitle,
    required this.content,
  });

  final String chapterTitle;
  final String content;

  @override
  State<ReaderContentEditSheet> createState() => _ReaderContentEditSheetState();
}

class _ReaderContentEditSheetState extends State<ReaderContentEditSheet> {
  late final _controller = TextEditingController(text: widget.content);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppSettingsSheet(
    title: widget.chapterTitle.isEmpty
        ? context.l10n.editSourceContent
        : '编辑：${widget.chapterTitle}',
    onSave: () => Navigator.pop(context, _controller.text),
    contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
    child: SizedBox(
      width: double.maxFinite,
      child: TextField(
        controller: _controller,
        maxLines: null,
        minLines: 8,
        decoration: const InputDecoration(labelText: '章节正文'),
      ),
    ),
  );
}
