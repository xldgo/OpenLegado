import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../l10n/app_localization.dart';

/// 管理列表共用卡片与交互壳；数据、选择状态和持久化由页面负责。— Codex + UI
class ManagementListCard extends StatelessWidget {
  const ManagementListCard({
    super.key,
    required this.information,
    required this.isEnabled,
    required this.onEnabledChanged,
    required this.onEdit,
    required this.onSelect,
    required this.onLongPress,
    this.menu,
    this.dragIndex,
    this.batchMode = false,
    this.selected = false,
    this.color,
  });

  final Widget information;
  final Widget? menu;
  final int? dragIndex;
  final bool isEnabled, batchMode, selected;
  final Color? color;
  final ValueChanged<bool>? onEnabledChanged;
  final VoidCallback onEdit, onSelect;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: color ?? theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: batchMode ? onSelect : onEdit,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            children: [
              if (batchMode)
                Checkbox(value: selected, onChanged: (_) => onSelect())
              else
                ReorderableDragStartListener(
                  index: dragIndex ?? 0,
                  enabled: dragIndex != null,
                  child: Tooltip(
                    message: context.l10n.sourceSortManual,
                    child: SizedBox.square(
                      dimension: 48,
                      child: Icon(
                        Symbols.drag_handle_rounded,
                        color: dragIndex == null
                            ? theme.disabledColor
                            : theme.colorScheme.outline,
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: information,
                  ),
                ),
              ),
              Switch(value: isEnabled, onChanged: onEnabledChanged),
              ?menu,
            ],
          ),
        ),
      ),
    );
  }

  /// 只抬升卡片自身，避免拖动预览在外边距处出现矩形背景。
  static Widget dragProxy(
    Widget child,
    int index,
    Animation<double> animation,
  ) => AnimatedBuilder(
    animation: animation,
    child: child,
    builder: (context, child) {
      final lift = Curves.easeInOut.transform(animation.value);
      return Transform.scale(
        scale: 1 + 0.02 * lift,
        child: CardTheme(
          data: CardTheme.of(context).copyWith(elevation: 4 * lift),
          child: child!,
        ),
      );
    },
  );
}
