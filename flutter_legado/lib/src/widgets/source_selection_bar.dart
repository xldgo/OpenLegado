import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../l10n/app_localization.dart';

import 'app_menu.dart';

/// 书源与订阅源共用的四项等宽多选操作栏。
class SourceSelectionBar extends StatelessWidget {
  const SourceSelectionBar({
    super.key,
    required this.selectedCount,
    required this.totalCount,
    required this.allSelected,
    required this.onToggleAll,
    required this.onInvert,
    required this.onDelete,
    required this.menuItems,
    required this.onMenuSelected,
  });

  final int selectedCount;
  final int totalCount;
  final bool allSelected;
  final VoidCallback onToggleAll;
  final VoidCallback onInvert;
  final VoidCallback onDelete;
  final List<AppMenuEntry<String>> menuItems;
  final ValueChanged<String> onMenuSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    Widget content(IconData icon, String label, Color color, bool enabled) {
      final foreground = enabled ? color : color.withValues(alpha: 0.35);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: foreground),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: foreground),
            ),
          ],
        ),
      );
    }

    Widget action(
      IconData icon,
      String label,
      VoidCallback? onTap, {
      Color? color,
    }) {
      return Expanded(
        child: Semantics(
          button: true,
          enabled: onTap != null,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: content(
              icon,
              label,
              color ?? colors.onSurface,
              onTap != null,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(
            color: colors.outlineVariant.withValues(alpha: 0.6),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              action(
                allSelected
                    ? Symbols.check_box_rounded
                    : Symbols.check_box_outline_blank_rounded,
                context.l10n.selectAllCount(selectedCount, totalCount),
                totalCount == 0 ? null : onToggleAll,
              ),
              action(
                Symbols.flip_rounded,
                context.l10n.invertSelection,
                totalCount == 0 ? null : onInvert,
              ),
              action(
                Symbols.delete_rounded,
                context.l10n.delete,
                selectedCount == 0 ? null : onDelete,
                color: colors.error,
              ),
              Expanded(
                child: AppMenuButton<String>(
                  tooltip: context.l10n.more,
                  enabled: selectedCount > 0,
                  onSelected: onMenuSelected,
                  itemBuilder: (_) => menuItems,
                  child: content(
                    Symbols.more_horiz_rounded,
                    context.l10n.more,
                    colors.onSurface,
                    selectedCount > 0,
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
