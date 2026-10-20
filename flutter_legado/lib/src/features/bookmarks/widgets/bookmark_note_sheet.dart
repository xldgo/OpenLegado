import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localization.dart';

/// 新增书签与编辑备注共用输入，保存完成前保留当前输入。— Codex + UI
class BookmarkNoteSheet extends StatefulWidget {
  const BookmarkNoteSheet({
    super.key,
    required this.bookText,
    required this.chapterName,
    required this.onSave,
    this.initialNote = '',
  });

  final String bookText;
  final String chapterName;
  final String initialNote;
  final Future<void> Function(String note) onSave;

  static Future<bool?> show({
    required BuildContext context,
    required String bookText,
    required String chapterName,
    required Future<void> Function(String note) onSave,
    String initialNote = '',
  }) => showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    // 编辑器通过按钮或系统返回退出，遮罩和拖拽不直接丢弃正在编辑的内容。
    isDismissible: false,
    enableDrag: false,
    showDragHandle: false,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (_) => BookmarkNoteSheet(
      bookText: bookText,
      chapterName: chapterName,
      initialNote: initialNote,
      onSave: onSave,
    ),
  );

  @override
  State<BookmarkNoteSheet> createState() => _BookmarkNoteSheetState();
}

class _BookmarkNoteSheetState extends State<BookmarkNoteSheet> {
  late final TextEditingController _originalController = TextEditingController(
    text: widget.bookText,
  );
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialNote,
  );
  bool _saving = false;
  bool _confirmingClose = false;
  String? _error;

  bool get _dirty => _controller.text != widget.initialNote;

  @override
  void dispose() {
    _originalController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (_saving || _confirmingClose) return;
    if (_dirty) {
      _confirmingClose = true;
      final discard = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.l10n.unsavedChanges),
          content: Text(ctx.l10n.bookmarkDiscardNote),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.l10n.bookmarkKeepEditing),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.l10n.discard),
            ),
          ],
        ),
      );
      _confirmingClose = false;
      if (discard != true || !mounted) return;
    }
    if (mounted) Navigator.pop(context, false);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(_controller.text);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = context.l10n.bookmarkNoteSaveFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope<bool>(
      canPop: !_saving && !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _saving ? null : _close,
                      tooltip: l10n.close,
                      icon: const Icon(Icons.close),
                    ),
                    Expanded(
                      child: Text(
                        widget.chapterName,
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('bookmark-note-save'),
                      onPressed: _saving ? null : _save,
                      tooltip: _saving ? l10n.bookmarkNoteSaving : l10n.save,
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.bookText.isNotEmpty) ...[
                        TextField(
                          key: const ValueKey('bookmark-original'),
                          controller: _originalController,
                          readOnly: true,
                          minLines: 2,
                          maxLines: 5,
                          keyboardType: TextInputType.multiline,
                          decoration: InputDecoration(
                            labelText: l10n.bookmarkOriginalText,
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextField(
                        key: const ValueKey('bookmark-note'),
                        controller: _controller,
                        autofocus: true,
                        enabled: !_saving,
                        minLines: 3,
                        maxLines: 6,
                        keyboardType: TextInputType.multiline,
                        decoration: InputDecoration(
                          labelText: l10n.bookmarkNoteLabel,
                          alignLabelWithHint: true,
                          errorText: _error,
                          errorMaxLines: 3,
                        ),
                        onChanged: (_) => setState(() => _error = null),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
