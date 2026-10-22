import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 动作标识与保存顺序保持稳定，新增动作追加到默认列表。
enum ReaderSelectionAction {
  copy('复制'),
  share('分享'),
  browser('浏览器'),
  aloud('朗读'),
  bookmark('书签'),
  highlight('高亮'),
  dictionary('词典'),
  replace('替换'),
  searchContent('搜正文');

  const ReaderSelectionAction(this.label);
  final String label;
}

enum SelectionMenuGroup { primary, collapsed, hidden }

class SelectionMenuItem {
  const SelectionMenuItem(this.action, this.group);
  final ReaderSelectionAction action;
  final SelectionMenuGroup group;
}

/// 阅读器选区菜单配置，界面只编辑快照，保存后统一通知各阅读入口。
class ReaderSelectionMenuConfig {
  ReaderSelectionMenuConfig({
    List<SelectionMenuItem>? items,
    this.expanded = false,
    this.showIcons = true,
  }) : items = List.unmodifiable(items ?? defaultItems);

  static const storageKey = 'reader_selection_menu_v1';
  static const defaultItems = [
    SelectionMenuItem(ReaderSelectionAction.copy, SelectionMenuGroup.primary),
    SelectionMenuItem(ReaderSelectionAction.share, SelectionMenuGroup.primary),
    SelectionMenuItem(
      ReaderSelectionAction.browser,
      SelectionMenuGroup.primary,
    ),
    SelectionMenuItem(ReaderSelectionAction.aloud, SelectionMenuGroup.primary),
    SelectionMenuItem(
      ReaderSelectionAction.bookmark,
      SelectionMenuGroup.primary,
    ),
    SelectionMenuItem(
      ReaderSelectionAction.highlight,
      SelectionMenuGroup.collapsed,
    ),
    SelectionMenuItem(
      ReaderSelectionAction.dictionary,
      SelectionMenuGroup.collapsed,
    ),
    SelectionMenuItem(
      ReaderSelectionAction.replace,
      SelectionMenuGroup.collapsed,
    ),
    SelectionMenuItem(
      ReaderSelectionAction.searchContent,
      SelectionMenuGroup.collapsed,
    ),
  ];

  final List<SelectionMenuItem> items;
  final bool expanded;
  final bool showIcons;

  List<SelectionMenuItem> inGroup(SelectionMenuGroup group) =>
      items.where((item) => item.group == group).toList();

  List<SelectionMenuItem> get visibleItems =>
      items.where((item) => item.group != SelectionMenuGroup.hidden).toList();

  ReaderSelectionMenuConfig copyWith({
    List<SelectionMenuItem>? items,
    bool? expanded,
    bool? showIcons,
  }) => ReaderSelectionMenuConfig(
    items: items ?? this.items,
    expanded: expanded ?? this.expanded,
    showIcons: showIcons ?? this.showIcons,
  );

  ReaderSelectionMenuConfig moveToGroup(
    ReaderSelectionAction action,
    SelectionMenuGroup group,
  ) => copyWith(
    items: [
      for (final item in items)
        item.action == action ? SelectionMenuItem(action, group) : item,
    ],
  );

  /// 只调整同组条目的槽位，其他组的顺序不受拖动影响。
  ReaderSelectionMenuConfig reorder(
    SelectionMenuGroup group,
    int from,
    int to,
  ) {
    final groupItems = inGroup(group);
    if (from < 0 ||
        to < 0 ||
        from >= groupItems.length ||
        to >= groupItems.length) {
      return this;
    }
    groupItems.insert(to, groupItems.removeAt(from));
    var index = 0;
    return copyWith(
      items: [
        for (final item in items)
          item.group == group ? groupItems[index++] : item,
      ],
    );
  }

  String encode() => jsonEncode({
    'version': 1,
    'expanded': expanded,
    'showIcons': showIcons,
    'items': [
      for (final item in items)
        {'action': item.action.name, 'group': item.group.name},
    ],
  });

  static ReaderSelectionMenuConfig decode(String? raw) {
    if (raw == null) return ReaderSelectionMenuConfig();
    try {
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic> ||
          data['version'] != 1 ||
          data['items'] is! List) {
        return ReaderSelectionMenuConfig();
      }
      final items = <SelectionMenuItem>[];
      final seen = <ReaderSelectionAction>{};
      for (final row in data['items'] as List) {
        if (row is! Map<String, dynamic>) continue;
        final action = ReaderSelectionAction.values
            .where((a) => a.name == row['action'])
            .firstOrNull;
        final group = SelectionMenuGroup.values
            .where((g) => g.name == row['group'])
            .firstOrNull;
        if (action != null && group != null && seen.add(action)) {
          items.add(SelectionMenuItem(action, group));
        }
      }
      // 忽略旧/未知标识，补齐新增动作；已有隐藏状态与顺序保持不变。
      items.addAll(defaultItems.where((item) => !seen.contains(item.action)));
      return ReaderSelectionMenuConfig(
        items: items,
        expanded: data['expanded'] == true,
        showIcons: data['showIcons'] != false,
      );
    } on FormatException {
      return ReaderSelectionMenuConfig();
    }
  }

  static Future<ReaderSelectionMenuConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.get(storageKey);
    return decode(value is String ? value : null);
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(storageKey, encode())) {
      throw StateError('无法保存选区菜单配置');
    }
  }
}

final readerSelectionMenuProvider =
    NotifierProvider<ReaderSelectionMenuNotifier, ReaderSelectionMenuConfig>(
      ReaderSelectionMenuNotifier.new,
    );

class ReaderSelectionMenuNotifier extends Notifier<ReaderSelectionMenuConfig> {
  int _revision = 0;

  @override
  ReaderSelectionMenuConfig build() {
    unawaited(_load());
    return ReaderSelectionMenuConfig();
  }

  Future<void> _load() async {
    final revision = _revision;
    final config = await ReaderSelectionMenuConfig.load();
    if (ref.mounted && revision == _revision) state = config;
  }

  Future<void> save(ReaderSelectionMenuConfig config) async {
    ++_revision;
    await config.save();
    if (ref.mounted) state = config;
  }
}
