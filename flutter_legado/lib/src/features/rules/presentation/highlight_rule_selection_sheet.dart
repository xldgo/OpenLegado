import 'package:material_ui/material_ui.dart';

import '../../../domain/models/highlight_rule.dart';
import '../../../widgets/app_settings_sheet.dart';
import '../../../widgets/bottom_sheet_widget.dart';

Future<List<HighlightRule>?> selectHighlightRules(
  BuildContext context, {
  required String title,
  required List<HighlightRule> rules,
  required Set<String> existing,
}) => AppBottomSheet.showContent<List<HighlightRule>>(
  context: context,
  builder: (_) => _Selection(title: title, rules: rules, existing: existing),
);

class _Selection extends StatefulWidget {
  const _Selection({
    required this.title,
    required this.rules,
    required this.existing,
  });
  final String title;
  final List<HighlightRule> rules;
  final Set<String> existing;
  @override
  State<_Selection> createState() => _SelectionState();
}

class _SelectionState extends State<_Selection> {
  late final selected = widget.rules
      .where((r) => !widget.existing.contains(r.uuid))
      .toSet();
  @override
  Widget build(BuildContext context) => AppSettingsSheet(
    title: widget.title,
    onSave: selected.isEmpty
        ? null
        : () => Navigator.pop(context, selected.toList()),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final rule in widget.rules)
          CheckboxListTile(
            value: selected.contains(rule),
            onChanged: (v) => setState(() {
              v == true ? selected.add(rule) : selected.remove(rule);
            }),
            title: Text(rule.displayName),
            subtitle: Text(
              widget.existing.contains(rule.uuid) ? '已存在，选中后覆盖' : rule.pattern,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    ),
  );
}
