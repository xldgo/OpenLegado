import 'package:material_ui/material_ui.dart';

import '../../../domain/models/general_settings.dart';
import '../../../l10n/app_localization.dart';
import '../../../widgets/app_settings_form.dart';
import '../../../widgets/app_settings_sheet.dart';

/// 行数草稿只限制输入框高度，确认后由设置页持久化。— Codex + UI
class SourceEditorLinesSheet extends StatefulWidget {
  const SourceEditorLinesSheet({super.key, required this.initial});
  final int initial;

  @override
  State<SourceEditorLinesSheet> createState() => _SourceEditorLinesSheetState();
}

class _SourceEditorLinesSheetState extends State<SourceEditorLinesSheet> {
  late bool _unlimited = widget.initial == 0;
  late final _text = TextEditingController(
    text:
        '${widget.initial == 0 ? GeneralSettings.minimumSourceEditMaxLines : widget.initial}',
  );
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _save() {
    final lines = _unlimited ? 0 : int.tryParse(_text.text.trim());
    if (lines == null ||
        (!_unlimited && lines < GeneralSettings.minimumSourceEditMaxLines)) {
      setState(() => _error = context.l10n.sourceEditorLinesInvalid);
      return;
    }
    Navigator.pop(context, lines);
  }

  @override
  Widget build(BuildContext context) => AppSettingsSheet(
    title: context.l10n.advancedSourceEditorMaxLines,
    onSave: _save,
    contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
    child: AppSettingsForm(
      description: context.l10n.sourceEditorLinesDescription,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.l10n.sourceEditorLinesUnlimited),
          value: _unlimited,
          onChanged: (value) => setState(() {
            _unlimited = value;
            _error = null;
          }),
        ),
        if (!_unlimited)
          TextField(
            controller: _text,
            keyboardType: TextInputType.number,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              labelText: context.l10n.advancedSourceEditorMaxLines,
              errorText: _error,
            ),
          ),
      ],
    ),
  );
}
