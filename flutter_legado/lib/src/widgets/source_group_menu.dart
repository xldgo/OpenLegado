import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../l10n/app_localization.dart';
import 'app_menu.dart';

typedef SourceGroupFilter = ({String value, String label});

/// 书源与订阅源共用分组入口；筛选项、选中状态和操作由页面提供。— Codex + UI
class SourceGroupMenuButton extends StatelessWidget {
  const SourceGroupMenuButton({
    super.key,
    required this.filters,
    required this.onSelected,
    this.selectedValue,
  });

  final List<SourceGroupFilter> filters;
  final String? selectedValue;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => AppMenuButton<String>(
    icon: const Icon(Symbols.groups_rounded),
    tooltip: context.l10n.group,
    onSelected: onSelected,
    itemBuilder: (context) => [
      AppMenuItem(
        value: 'group_manage',
        child: Text(context.l10n.groupManagement),
      ),
      const AppMenuDivider(),
      for (final filter in filters)
        AppMenuItem(
          value: filter.value,
          checked: selectedValue == filter.value,
          child: Text(filter.label),
        ),
    ],
  );
}
