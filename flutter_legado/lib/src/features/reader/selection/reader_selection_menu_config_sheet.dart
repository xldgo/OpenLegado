import 'package:material_ui/material_ui.dart';

import '../../../widgets/settings_widgets.dart';
import 'reader_selection_menu_config.dart';

extension ReaderSelectionActionIcon on ReaderSelectionAction {
  IconData get icon => switch (this) {
    ReaderSelectionAction.copy => Icons.copy_outlined,
    ReaderSelectionAction.share => Icons.share_outlined,
    ReaderSelectionAction.browser => Icons.language_outlined,
    ReaderSelectionAction.aloud => Icons.volume_up_outlined,
    ReaderSelectionAction.bookmark => Icons.bookmark_border,
    ReaderSelectionAction.highlight => Icons.border_color_outlined,
    ReaderSelectionAction.dictionary => Icons.menu_book_outlined,
    ReaderSelectionAction.replace => Icons.find_replace_outlined,
    ReaderSelectionAction.searchContent => Icons.search,
  };
}

/// 仿上游管理主要、折叠与隐藏项目，保存一次应用整个配置。
class ReaderSelectionMenuConfigSheet extends StatefulWidget {
  const ReaderSelectionMenuConfigSheet({super.key, required this.config});
  final ReaderSelectionMenuConfig config;

  static Future<ReaderSelectionMenuConfig?> show(
    BuildContext context,
    ReaderSelectionMenuConfig config,
  ) => showModalBottomSheet<ReaderSelectionMenuConfig>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.8,
      child: ReaderSelectionMenuConfigSheet(config: config),
    ),
  );

  @override
  State<ReaderSelectionMenuConfigSheet> createState() =>
      _ReaderSelectionMenuConfigSheetState();
}

class _ReaderSelectionMenuConfigSheetState
    extends State<ReaderSelectionMenuConfigSheet> {
  late var _draft = widget.config;
  final _expandedGroups = {
    SelectionMenuGroup.primary,
    SelectionMenuGroup.collapsed,
  };

  void _move(ReaderSelectionAction action, SelectionMenuGroup group) =>
      setState(() => _draft = _draft.moveToGroup(action, group));

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '选区菜单管理',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: '保存菜单配置',
                icon: const Icon(Icons.save_outlined),
                onPressed: () => Navigator.pop(context, _draft),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              children: [
                SettingsGroup(
                  showDividers: false,
                  children: [
                    SettingSwitchRow(
                      title: '多行展开菜单',
                      value: _draft.expanded,
                      onChanged: (value) => setState(
                        () => _draft = _draft.copyWith(expanded: value),
                      ),
                    ),
                    SettingSwitchRow(
                      title: '显示菜单图标',
                      value: _draft.showIcons,
                      onChanged: (value) => setState(
                        () => _draft = _draft.copyWith(showIcons: value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _group(SelectionMenuGroup.primary, '主要菜单'),
                const SizedBox(height: 12),
                _group(
                  SelectionMenuGroup.collapsed,
                  '折叠菜单',
                  subtitle: _draft.expanded ? '多行模式下合并展示' : null,
                ),
                const SizedBox(height: 12),
                _group(SelectionMenuGroup.hidden, '隐藏项目'),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _group(SelectionMenuGroup group, String title, {String? subtitle}) {
    final items = _draft.inGroup(group);
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: ValueKey(group),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle),
        initiallyExpanded: _expandedGroups.contains(group),
        onExpansionChanged: (expanded) {
          if (expanded) {
            _expandedGroups.add(group);
          } else {
            _expandedGroups.remove(group);
          }
        },
        shape: const Border(),
        collapsedShape: const Border(),
        children: [
          if (group == SelectionMenuGroup.hidden)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: items.isEmpty
                  ? const Text('没有隐藏项目')
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final item in items)
                          ActionChip(
                            avatar: _draft.showIcons
                                ? Icon(item.action.icon, size: 16)
                                : null,
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(item.action.label),
                                const SizedBox(width: 4),
                                const Icon(Icons.add, size: 16),
                              ],
                            ),
                            tooltip: '恢复${item.action.label}到主要菜单',
                            onPressed: () =>
                                _move(item.action, SelectionMenuGroup.primary),
                          ),
                      ],
                    ),
            )
          else if (items.isEmpty)
            const Padding(padding: EdgeInsets.all(12), child: Text('暂无项目'))
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: items.length,
              onReorderItem: (from, to) =>
                  setState(() => _draft = _draft.reorder(group, from, to)),
              proxyDecorator: (child, _, animation) => Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(12),
                child: child,
              ),
              itemBuilder: (context, index) {
                final action = items[index].action;
                final target = group == SelectionMenuGroup.primary
                    ? SelectionMenuGroup.collapsed
                    : SelectionMenuGroup.primary;
                return Semantics(
                  key: ValueKey(action),
                  onIncrease: index < items.length - 1
                      ? () => setState(
                          () =>
                              _draft = _draft.reorder(group, index, index + 1),
                        )
                      : null,
                  onDecrease: index > 0
                      ? () => setState(
                          () =>
                              _draft = _draft.reorder(group, index, index - 1),
                        )
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                    child: Material(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                      child: ListTile(
                        leading: _draft.showIcons
                            ? Icon(action.icon, size: 20)
                            : null,
                        title: Text(action.label),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: target == SelectionMenuGroup.primary
                                  ? '移到主要菜单'
                                  : '移到折叠菜单',
                              icon: Icon(
                                target == SelectionMenuGroup.primary
                                    ? Icons.add
                                    : Icons.remove,
                              ),
                              onPressed: () => _move(action, target),
                            ),
                            IconButton(
                              tooltip: '隐藏${action.label}',
                              icon: const Icon(Icons.visibility_off_outlined),
                              onPressed: () =>
                                  _move(action, SelectionMenuGroup.hidden),
                            ),
                            ReorderableDragStartListener(
                              index: index,
                              child: Tooltip(
                                message: '拖动排序${action.label}',
                                child: const SizedBox(
                                  width: 36,
                                  height: 48,
                                  child: Icon(Icons.drag_handle),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
