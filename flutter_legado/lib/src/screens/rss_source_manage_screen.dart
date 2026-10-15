import '../providers/rss_repository_provider.dart';
import '../widgets/dynamic_search_app_bar.dart';
import '../l10n/app_localization.dart';
import '../widgets/app_menu.dart';

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../widgets/app_scaffold.dart';
import '../widgets/md3_fast_scroller.dart';
import '../widgets/source_selection_bar.dart';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../services/bridge_http.dart';

import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../providers/rss/rss_notifier.dart' show syncDefaultRssSources;
import '../routes.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/help/help_assets.dart';
import '../widgets/help/show_help.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_view.dart';
import '../widgets/settings_widgets.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/rss_group_manage_dialog.dart';
import '../utils/error_message.dart';
import 'rss_source_edit_screen.dart';
import 'rss_source_import_confirm_screen.dart';

/// 安卓端 AppPattern.splitGroupRegex：[,;，；]
final RegExp _splitGroupRegex = RegExp(r'[,;，；]');

/// 订阅源管理页（对标原版 RssSourceActivity）
///
/// - 顶栏：搜索框（特殊过滤词：启用/禁用/需登录/未分组/group:分组名）
///   + 分组菜单（分组管理/特殊分组/动态分组）+ 更多菜单（新增/导入/帮助）
/// - 列表项：勾选框 + 源名(分组) + 启用开关 + 编辑 + 更多（置顶/置底/删除）
/// - 长按名称区域排序（customOrder），常显勾选框进入原地多选
/// - 批量操作：全选/反选/删除 + 更多（启停/分组/置顶置底/导出/分享/区间）
class RssSourceManageScreen extends ConsumerStatefulWidget {
  const RssSourceManageScreen({super.key});

  @override
  ConsumerState<RssSourceManageScreen> createState() =>
      _RssSourceManageScreenState();
}

class _RssSourceManageScreenState extends ConsumerState<RssSourceManageScreen> {
  // [UI_SYNC_REFACTOR R3] 快速滚动条控制器
  final ScrollController _fsController = ScrollController();
  final _searchCtrl = TextEditingController();
  bool _searchExpanded = false;

  List<RssSource> _sources = [];
  bool _loading = true;
  String? _error;

  /// 搜索关键词（驱动全部过滤，对标原版 searchView 单一入口）
  String _keyword = '';

  final Set<String> _selected = {};

  /// 直接由勾选集合决定多选状态，清空后自动收起底栏。
  bool get _batchMode => _selected.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _fsController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sources = await ref
          .read(rssSourceRepositoryProvider)
          .getRssSources();
      // 对标原版默认 customOrder 升序
      sources.sort((a, b) => a.customOrder.compareTo(b.customOrder));
      if (!mounted) return;
      setState(() {
        _sources = sources;
        _loading = false;
        _selected.removeWhere(
          (url) => sources.every((s) => s.sourceUrl != url),
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errorMessage(e);
        _loading = false;
      });
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // ===== 过滤（对标原版 upSourceFlow） =====

  List<String> _splitGroups(String? sourceGroup) {
    if (sourceGroup == null || sourceGroup.isEmpty) return const [];
    return sourceGroup
        .split(_splitGroupRegex)
        .map((g) => g.trim())
        .where((g) => g.isNotEmpty)
        .toList();
  }

  /// 聚合所有源分组（LinkedHashSet 保序，对标原版 linkedSetOf）
  List<String> get _groups {
    final set = <String>{};
    for (final s in _sources) {
      set.addAll(_splitGroups(s.sourceGroup));
    }
    return set.toList();
  }

  // 显示词与筛选控制值分离，保留旧中文查询并兼容英文输入。
  String get _normalizedKeyword {
    final current = context.l10n;
    final english = lookupAppLocalizations(const Locale('en'));
    final query = _keyword.trim();
    final labels = {
      current.enabled: '启用',
      current.disabled: '禁用',
      current.loginRequired: '需登录',
      current.ungrouped: '未分组',
      english.enabled: '启用',
      english.disabled: '禁用',
      english.loginRequired: '需登录',
      english.ungrouped: '未分组',
    };
    return labels[query] ?? query;
  }

  List<RssSource> get _filtered {
    final kw = _normalizedKeyword;
    if (kw.isEmpty) return _sources;
    switch (kw) {
      case '启用':
        return _sources.where((s) => s.enabled).toList();
      case '禁用':
        return _sources.where((s) => !s.enabled).toList();
      case '需登录':
        return _sources
            .where((s) => (s.loginUrl ?? '').trim().isNotEmpty)
            .toList();
      case '未分组':
        return _sources
            .where((s) => _splitGroups(s.sourceGroup).isEmpty)
            .toList();
    }
    if (kw.startsWith('group:')) {
      final group = kw.substring('group:'.length);
      return _sources
          .where((s) => _splitGroups(s.sourceGroup).contains(group))
          .toList();
    }
    final lower = kw.toLowerCase();
    return _sources
        .where(
          (s) =>
              s.sourceName.toLowerCase().contains(lower) ||
              s.sourceUrl.toLowerCase().contains(lower),
        )
        .toList();
  }

  /// 分组菜单点击 → 写入搜索框（对标原版 searchView.setQuery）
  void _setQuery(String query) {
    _searchCtrl.text = switch (query) {
      '启用' => context.l10n.enabled,
      '禁用' => context.l10n.disabled,
      '需登录' => context.l10n.loginRequired,
      '未分组' => context.l10n.ungrouped,
      _ => query,
    };
    setState(() => _keyword = query);
  }

  // ===== 构建 =====

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_batchMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _batchMode) _exitBatch();
      },
      child: AppScaffold(
        // [GLOBALCOMP B4] 页壳统一：AppScaffold（行为等价直通 Scaffold）
        topBar: _buildAppBar(),
        body: _buildBody(),
        bottomBar: _batchMode ? _buildBatchBottomBar() : null,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return DynamicSearchAppBar(
      leading: _batchMode
          ? IconButton(
              icon: const Icon(Symbols.close_rounded),
              tooltip: context.l10n.exitSelection,
              onPressed: _exitBatch,
            )
          : null,
      title: context.l10n.rssSourceManagement,
      searchController: _searchCtrl,
      searchHint: context.l10n.searchRssSources,
      expanded: _searchExpanded,
      onExpandedChanged: (value) => setState(() => _searchExpanded = value),
      onChanged: (v) => setState(() => _keyword = v),

      actions: [
        // 分组菜单（对标原版 rss_source.xml menu_group 子菜单）
        AppMenuButton<String>(
          icon: const Icon(Symbols.groups_rounded),
          tooltip: context.l10n.group,
          onSelected: _handleGroupAction,
          itemBuilder: (context) => [
            AppMenuItem(
              enabled: false,
              child: Text(
                context.l10n.group,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            AppMenuItem(
              value: 'group_manage',
              child: Text(context.l10n.groupManagement),
            ),
            AppMenuItem(
              value: '启用',
              checked: _normalizedKeyword == '启用',
              child: Text(context.l10n.enabled),
            ),
            AppMenuItem(
              value: '禁用',
              checked: _normalizedKeyword == '禁用',
              child: Text(context.l10n.disabled),
            ),
            AppMenuItem(
              value: '需登录',
              checked: _normalizedKeyword == '需登录',
              child: Text(context.l10n.loginRequired),
            ),
            AppMenuItem(
              value: '未分组',
              checked: _normalizedKeyword == '未分组',
              child: Text(context.l10n.ungrouped),
            ),
            for (final group in _groups)
              AppMenuItem(
                value: 'group:$group',
                checked: _normalizedKeyword == 'group:$group',
                child: Text(group),
              ),
          ],
        ),
        // 更多菜单（对标原版 rss_source.xml 溢出菜单）
        AppMenuButton<String>(
          tooltip: context.l10n.more,
          onSelected: _handleAction,
          itemBuilder: (_) => [
            AppMenuItem(
              value: 'new',
              child: _MenuRow(
                icon: Symbols.add_rounded,
                label: context.l10n.addRssSource,
              ),
            ),
            AppMenuItem(
              value: 'import_file',
              child: _MenuRow(
                icon: Symbols.download_rounded,
                label: context.l10n.importLocal,
              ),
            ),
            AppMenuItem(
              value: 'import_url',
              child: _MenuRow(
                icon: Symbols.cloud_download_rounded,
                label: context.l10n.importOnline,
              ),
            ),
            AppMenuItem(
              value: 'import_qr',
              child: _MenuRow(
                icon: Symbols.qr_code_rounded,
                label: context.l10n.importQrCode,
              ),
            ),
            AppMenuItem(
              value: 'import_default',
              child: _MenuRow(
                icon: Symbols.auto_fix_high_rounded,
                label: context.l10n.importDefaultRules,
              ),
            ),
            // 规则订阅入口（对标原版 RssFragment 列表头部
            // 「规则订阅」header item → RuleSubActivity；Flutter 侧
            // 统一收进溢出菜单，iOS 菜单惯例）
            AppMenuItem(
              value: 'rule_sub',
              child: _MenuRow(
                icon: Symbols.rss_feed_rounded,
                label: context.l10n.ruleSubscriptions,
              ),
            ),
            AppMenuItem(
              value: 'help',
              child: _MenuRow(
                icon: Symbols.help_rounded,
                label: context.l10n.help,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _exitBatch() {
    setState(() {
      _selected.clear();
    });
  }

  /// 与书源管理共用四项等宽底栏，多选时显示。
  Widget _buildBatchBottomBar() {
    return SourceSelectionBar(
      selectedCount: _selected.length,
      totalCount: _filtered.length,
      allSelected: _isAllSelected,
      onToggleAll: () => setState(() {
        if (_isAllSelected) {
          _selected.clear();
        } else {
          _selected.addAll(_filtered.map((s) => s.sourceUrl));
        }
      }),
      onInvert: () => setState(() {
        for (final source in _filtered) {
          if (!_selected.remove(source.sourceUrl)) {
            _selected.add(source.sourceUrl);
          }
        }
      }),
      onDelete: () => _handleBatchAction('delete'),
      onMenuSelected: _handleBatchAction,
      menuItems: [
        AppMenuItem(value: 'enable', child: Text(context.l10n.enableSelected)),
        AppMenuItem(
          value: 'disable',
          child: Text(context.l10n.disableSelected),
        ),
        AppMenuItem(value: 'add_group', child: Text(context.l10n.addToGroup)),
        AppMenuItem(
          value: 'remove_group',
          child: Text(context.l10n.removeGroup),
        ),
        AppMenuItem(value: 'top', child: Text(context.l10n.pinSelected)),
        AppMenuItem(value: 'bottom', child: Text(context.l10n.bottomSelected)),
        AppMenuItem(value: 'export', child: Text(context.l10n.exportSelected)),
        AppMenuItem(value: 'share', child: Text(context.l10n.shareSources)),
        AppMenuItem(
          value: 'select_range',
          child: Text(context.l10n.selectRange),
        ),
      ],
    );
  }

  bool get _isAllSelected =>
      _filtered.isNotEmpty &&
      _filtered.every((s) => _selected.contains(s.sourceUrl));

  Widget _buildBody() {
    if (_loading && _sources.isEmpty) {
      return LoadingIndicator(message: context.l10n.loadingRssSources);
    }
    if (_error != null && _sources.isEmpty) {
      return ErrorView(message: _error!, onRetry: _load);
    }
    final list = _filtered;
    if (list.isEmpty) {
      return EmptyState(
        icon: Symbols.rss_feed_rounded,
        title: _sources.isEmpty
            ? context.l10n.emptyRssSources
            : context.l10n.noMatchingRssSources,
        subtitle: _sources.isEmpty ? context.l10n.addRssSourceHint : null,
      );
    }
    return Md3FastScroller(
      controller: _fsController,
      child: ReorderableListView.builder(
        scrollController: _fsController,
        buildDefaultDragHandles: false,
        itemCount: list.length,
        itemBuilder: (context, index) => KeyedSubtree(
          key: ValueKey(list[index].sourceUrl),
          child: _buildSourceItem(context, list[index], dragIndex: index),
        ),
        onReorderItem: _reorderVisible,
      ),
    );
  }

  /// 列表项（对标原版 item_rss_source：勾选框 + 源名(分组) +
  /// Switch + 编辑 + 更多）
  Widget _buildSourceItem(
    BuildContext context,
    RssSource source, {
    required int dragIndex,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final group = source.sourceGroup ?? '';
    final name = Container(
      color: Colors.transparent,
      constraints: const BoxConstraints(minHeight: 48),
      alignment: Alignment.centerLeft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            source.sourceName.isEmpty ? source.sourceUrl : source.sourceName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.start,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: colorScheme.onSurface),
          ),
          if (group.isNotEmpty)
            Text(
              group,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
        ],
      ),
    );
    return AbsorbPointer(
      absorbing: _loading,
      child: InkWell(
        onTap: () {
          if (_batchMode) {
            _toggleSelection(source.sourceUrl);
          } else {
            _openEdit(source);
          }
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
          child: Row(
            children: [
              // 勾选框（对标原版 cb_source：点击进入批量选择）
              Checkbox(
                value: _selected.contains(source.sourceUrl),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                onChanged: (_) => _toggleSelection(source.sourceUrl),
              ),
              Expanded(
                child: ReorderableDelayedDragStartListener(
                  index: dragIndex,
                  enabled: !_loading,
                  child: name,
                ),
              ),
              // 启用开关（对标原版 swt_enabled）
              Switch(
                value: source.enabled,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: (_) => _toggleSource(source),
              ),
              IconButton(
                icon: const Icon(Symbols.edit_rounded, size: 20),
                tooltip: context.l10n.edit,
                visualDensity: VisualDensity.compact,
                onPressed: () => _openEdit(source),
              ),
              IconButton(
                icon: const Icon(Symbols.more_vert_rounded, size: 20),
                tooltip: context.l10n.more,
                visualDensity: VisualDensity.compact,
                onPressed: () => _showSourceMenu(source),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleSelection(String sourceUrl) {
    setState(() {
      if (_selected.contains(sourceUrl)) {
        _selected.remove(sourceUrl);
      } else {
        _selected.add(sourceUrl);
      }
    });
  }

  // ===== 单源操作 =====

  Future<void> _openEdit(RssSource source) async {
    await Navigator.of(context).push<RssSource>(
      MaterialPageRoute(builder: (_) => RssSourceEditScreen(source: source)),
    );
    await _load();
  }

  Future<void> _toggleSource(RssSource source) async {
    final l10n = context.l10n;
    try {
      if (source.enabled) {
        await ref
            .read(rssSourceRepositoryProvider)
            .disableRssSource(source.sourceUrl);
      } else {
        await ref
            .read(rssSourceRepositoryProvider)
            .enableRssSource(source.sourceUrl);
      }
      await _load();
    } catch (e) {
      _toast(l10n.sourceEnabledToggleFailed(e.toString()));
    }
  }

  /// 单项菜单（对标原版 rss_source_item.xml：置顶/置底/删除）
  Future<void> _showSourceMenu(RssSource source) async {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 8, bottom: 4),
              child: SheetDragHandle(),
            ),
            ListTile(
              leading: const Icon(Symbols.vertical_align_top_rounded),
              title: Text(l10n.pinToTop),
              onTap: () => Navigator.pop(ctx, 'top'),
            ),
            ListTile(
              leading: const Icon(Symbols.vertical_align_bottom_rounded),
              title: Text(l10n.moveToBottom),
              onTap: () => Navigator.pop(ctx, 'bottom'),
            ),
            ListTile(
              leading: Icon(Symbols.delete_rounded, color: colorScheme.error),
              title: Text(
                l10n.delete,
                style: TextStyle(color: colorScheme.error),
              ),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case 'top':
        final index = _sources.indexOf(source);
        if (index > 0) await _reorder(index, 0);
      case 'bottom':
        final index = _sources.indexOf(source);
        if (index >= 0 && index < _sources.length - 1) {
          await _reorder(index, _sources.length - 1);
        }
      case 'delete':
        final confirmed = await showConfirmDialog(
          context,
          title: l10n.deleteRssSources,
          content: l10n.confirmDeleteNamedSource(source.sourceName),
          confirmText: l10n.delete,
          isDestructive: true,
        );
        if (confirmed && mounted) {
          try {
            await ref
                .read(rssSourceRepositoryProvider)
                .deleteRssSource(source.sourceUrl);
            await _load();
          } catch (e) {
            _toast(l10n.deleteFailed(e.toString()));
          }
        }
    }
  }

  /// 拖拽排序（对标原版 RssSourceAdapter itemTouchHelper：
  /// 移动后按序重排 customOrder，仅持久化发生变化的源）；
  /// onReorderItem 的 newIndex 已按移除项调整，无需手动修正
  Future<void> _reorder(int oldIndex, int newIndex) async {
    if (_loading ||
        oldIndex == newIndex ||
        oldIndex < 0 ||
        oldIndex >= _sources.length ||
        newIndex < 0 ||
        newIndex >= _sources.length) {
      return;
    }
    final list = List<RssSource>.of(_sources);
    final moved = list.removeAt(oldIndex);
    list.insert(newIndex, moved);
    await _saveOrder(list);
  }

  /// 筛选后的拖动只交换可见书源的位置，隐藏书源保留原位置。
  Future<void> _reorderVisible(int oldIndex, int newIndex) async {
    final visible = List<RssSource>.of(_filtered);
    if (_loading ||
        oldIndex == newIndex ||
        oldIndex < 0 ||
        oldIndex >= visible.length ||
        newIndex < 0 ||
        newIndex >= visible.length) {
      return;
    }
    visible.insert(newIndex, visible.removeAt(oldIndex));
    final urls = visible.map((s) => s.sourceUrl).toSet();
    final replacements = visible.iterator;
    final list = <RssSource>[];
    for (final source in _sources) {
      if (urls.contains(source.sourceUrl)) {
        replacements.moveNext();
        list.add(replacements.current);
      } else {
        list.add(source);
      }
    }
    await _saveOrder(list);
  }

  Future<void> _saveOrder(List<RssSource> list) async {
    final l10n = context.l10n;
    final changed = <RssSource>[];
    for (var i = 0; i < list.length; i++) {
      if (list[i].customOrder != i) {
        final updated = list[i].copyWith(customOrder: i);
        list[i] = updated;
        changed.add(updated);
      }
    }
    setState(() {
      _sources = list;
      _loading = true;
    });
    try {
      for (final s in changed) {
        await ref.read(rssSourceRepositoryProvider).updateRssSource(s);
      }
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      _toast(l10n.sortSaveFailed(e.toString()));
      await _load();
    }
  }

  // ===== 菜单处理 =====

  Future<void> _handleGroupAction(String value) async {
    if (value == 'group_manage') {
      final changed = await showDialog<bool>(
        context: context,
        builder: (_) => RssGroupManageDialog(sources: _sources),
      );
      if (changed == true) await _load();
      return;
    }
    // 再次点击当前过滤词时清除（原版无此行为，iOS 惯例补充）
    if (_normalizedKeyword == value) {
      _searchCtrl.clear();
      setState(() => _keyword = '');
      return;
    }
    _setQuery(value);
  }

  Future<void> _handleAction(String action) async {
    switch (action) {
      case 'new':
        await Navigator.of(context).push<RssSource>(
          MaterialPageRoute(builder: (_) => const RssSourceEditScreen()),
        );
        await _load();
      case 'import_file':
        await _importFromFile();
      case 'import_url':
        await _showImportUrlDialog();
      case 'import_qr':
        await _importFromQrCode();
      case 'import_default':
        await _importDefault();
      case 'rule_sub':
        // 对标原版 RssFragment 头部入口 → RuleSubActivity
        await Navigator.of(context).pushNamed(AppRoutes.ruleSub);
      case 'help':
        _showHelpSheet();
    }
  }

  // ===== 批量操作（对标原版 rss_source_sel.xml） =====

  Future<void> _handleBatchAction(String action) async {
    final l10n = context.l10n;
    if (_selected.isEmpty) {
      _toast(l10n.selectRssSourcesFirst);
      return;
    }
    final selectedSources = _sources
        .where((s) => _selected.contains(s.sourceUrl))
        .toList();
    switch (action) {
      case 'enable':
      case 'disable':
        final enable = action == 'enable';
        try {
          for (final s in selectedSources) {
            if (s.enabled != enable) {
              if (enable) {
                await ref
                    .read(rssSourceRepositoryProvider)
                    .enableRssSource(s.sourceUrl);
              } else {
                await ref
                    .read(rssSourceRepositoryProvider)
                    .disableRssSource(s.sourceUrl);
              }
            }
          }
          await _load();
          _toast(
            enable
                ? l10n.selectedRssSourcesEnabled
                : l10n.selectedRssSourcesDisabled,
          );
        } catch (e) {
          _toast(l10n.operationFailed(e.toString()));
        }
      case 'add_group':
        await _showAddGroupDialog();
      case 'remove_group':
        await _showRemoveGroupDialog();
      case 'top':
        await _batchMove(toTop: true);
      case 'bottom':
        await _batchMove(toTop: false);
      case 'export':
        await _exportSelected();
      case 'share':
        await _shareSelected();
      case 'select_range':
        _selectRange();
      case 'delete':
        final confirmed = await showConfirmDialog(
          context,
          title: l10n.deleteRssSources,
          content: l10n.confirmDeleteRssSourceCount(_selected.length),
          confirmText: l10n.delete,
          isDestructive: true,
        );
        if (!confirmed || !mounted) return;
        try {
          for (final s in selectedSources) {
            await ref
                .read(rssSourceRepositoryProvider)
                .deleteRssSource(s.sourceUrl);
          }
          _exitBatch();
          await _load();
          _toast(l10n.selectedRssSourcesDeleted);
        } catch (e) {
          _toast(l10n.deleteFailed(e.toString()));
          await _load();
        }
    }
  }

  /// 批量置顶/置底：重排整表 customOrder（对标原版 topSource/bottomSource）
  Future<void> _batchMove({required bool toTop}) async {
    final l10n = context.l10n;
    final sel = _sources.where((s) => _selected.contains(s.sourceUrl)).toList();
    final rest = _sources
        .where((s) => !_selected.contains(s.sourceUrl))
        .toList();
    final list = toTop ? [...sel, ...rest] : [...rest, ...sel];
    final changed = <RssSource>[];
    for (var i = 0; i < list.length; i++) {
      if (list[i].customOrder != i) {
        final updated = list[i].copyWith(customOrder: i);
        list[i] = updated;
        changed.add(updated);
      }
    }
    setState(() => _sources = list);
    try {
      for (final s in changed) {
        await ref.read(rssSourceRepositoryProvider).updateRssSource(s);
      }
      _toast(
        toTop ? l10n.selectedRssSourcesPinned : l10n.selectedRssSourcesBottom,
      );
    } catch (e) {
      _toast(l10n.operationFailed(e.toString()));
      await _load();
    }
  }

  /// 添加到分组（对标原版 addGroups：合并进各源 sourceGroup）
  Future<void> _showAddGroupDialog() async {
    final l10n = context.l10n;
    final group = await showDialog<String>(
      context: context,
      builder: (_) => _TextPromptDialog(
        title: l10n.addToGroup,
        hintText: l10n.groupNameHint,
        confirmLabel: l10n.confirm,
        autofocus: true,
      ),
    );
    if (group == null || group.trim().isEmpty || !mounted) return;
    final name = group.trim();
    try {
      for (final s in _sources.where((s) => _selected.contains(s.sourceUrl))) {
        final groups = _splitGroups(s.sourceGroup);
        if (groups.contains(name)) continue;
        final merged = [...groups, name].join(',');
        await ref
            .read(rssSourceRepositoryProvider)
            .updateRssSource(s.copyWith(sourceGroup: merged));
      }
      await _load();
      _toast(l10n.addedSourceGroup(name));
    } catch (e) {
      _toast(l10n.addGroupFailed(e.toString()));
    }
  }

  /// 移除分组（对标原版 removeGroups：从选中源已有分组中选择）
  Future<void> _showRemoveGroupDialog() async {
    final l10n = context.l10n;
    final groups = <String>{};
    for (final s in _sources.where((s) => _selected.contains(s.sourceUrl))) {
      groups.addAll(_splitGroups(s.sourceGroup));
    }
    if (groups.isEmpty) {
      _toast(l10n.noRemovableSourceGroups);
      return;
    }
    final group = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.removeGroup),
        children: [
          for (final g in groups.toList()..sort())
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, g),
              child: Text(g),
            ),
        ],
      ),
    );
    if (group == null || !mounted) return;
    try {
      for (final s in _sources.where((s) => _selected.contains(s.sourceUrl))) {
        final groups = _splitGroups(s.sourceGroup)..remove(group);
        await ref
            .read(rssSourceRepositoryProvider)
            .updateRssSource(
              s.copyWith(sourceGroup: groups.isEmpty ? null : groups.join(',')),
            );
      }
      await _load();
      _toast(l10n.removedSourceGroup(group));
    } catch (e) {
      _toast(l10n.removeGroupFailed(e.toString()));
    }
  }

  /// 导出选中（对标原版 exportSelection：JSON 复制到剪贴板）
  Future<void> _exportSelected() async {
    final l10n = context.l10n;
    try {
      final selectedSources = _sources
          .where((s) => _selected.contains(s.sourceUrl))
          .toList();
      final json = const JsonEncoder.withIndent('  ')
          .convert(selectedSources.map((s) => s.toJson()).toList());
      await Clipboard.setData(ClipboardData(text: json));
      _toast(l10n.exportedRssSourcesToClipboard(selectedSources.length));
      _exitBatch();
    } catch (e) {
      _toast(l10n.exportFailed(e.toString()));
    }
  }

  /// 分享源（对标原版 shareSource）
  Future<void> _shareSelected() async {
    final l10n = context.l10n;
    try {
      final selectedSources = _sources
          .where((s) => _selected.contains(s.sourceUrl))
          .toList();
      final json = jsonEncode(selectedSources.map((s) => s.toJson()).toList());
      await SharePlus.instance.share(
        ShareParams(
          text: json,
          subject: l10n.shareRssSourceCount(selectedSources.length),
        ),
      );
    } catch (e) {
      _toast(l10n.shareFailed(e.toString()));
    }
  }

  /// 选择区间（对标原版 checkSelectedInterval：
  /// 选中最小到最大索引之间的全部项）
  void _selectRange() {
    final list = _filtered;
    final indexes = <int>[];
    for (var i = 0; i < list.length; i++) {
      if (_selected.contains(list[i].sourceUrl)) indexes.add(i);
    }
    if (indexes.length < 2) {
      _toast(context.l10n.selectTwoRssSourcesFirst);
      return;
    }
    final min = indexes.reduce((a, b) => a < b ? a : b);
    final max = indexes.reduce((a, b) => a > b ? a : b);
    setState(() {
      for (var i = min; i <= max; i++) {
        _selected.add(list[i].sourceUrl);
      }
    });
  }

  // ===== 导入 =====

  /// 解析订阅源文本（JSON 数组或单个对象）
  List<Map<String, dynamic>> _parseSourcesText(String text) {
    final trimmed = text.trim();
    if (trimmed.startsWith('[')) {
      final decoded = jsonDecode(trimmed);
      if (decoded is! List) throw const FormatException('不是有效的订阅源数组');
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (trimmed.startsWith('{')) {
      final decoded = jsonDecode(trimmed);
      if (decoded is! Map) throw const FormatException('不是有效的订阅源对象');
      return [Map<String, dynamic>.from(decoded)];
    }
    throw const FormatException('格式错误，未解析到订阅源');
  }

  /// 候选订阅源 → 导入确认页（对标原版 comparisonSource 流程）
  Future<void> _parseAndConfirm(String text) async {
    final l10n = context.l10n;
    List<Map<String, dynamic>> candidates;
    try {
      candidates = _parseSourcesText(text);
    } catch (e) {
      _toast(l10n.invalidRssSources);
      return;
    }
    if (candidates.isEmpty) {
      _toast(l10n.invalidRssSources);
      return;
    }
    if (!mounted) return;
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RssSourceImportConfirmScreen(
          sources: candidates,
          localSources: _sources,
        ),
      ),
    );
    if (ok == true && mounted) {
      await _load();
      _toast(l10n.importFinished);
    }
  }

  /// 本地导入（对标原版 menu_import_local：txt/json 任选，解析层容错）
  Future<void> _importFromFile() async {
    final l10n = context.l10n;
    try {
      final picked = await FilePicker.pickFile();
      if (picked == null) return;
      final path = picked.path;
      if (path == null) {
        _toast(l10n.filePathUnavailable);
        return;
      }
      final text = await File(path).readAsString();
      if (!mounted) return;
      await _parseAndConfirm(text);
    } catch (e) {
      _toast(l10n.importFromFileFailed(e.toString()));
    }
  }

  /// 网络导入弹窗（对标原版 showImportDialog：URL 输入 + 历史记录）
  Future<void> _showImportUrlDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs
        .getString('rssSourceImportUrls')
        ?.split(',')
        .where((e) => e.trim().isNotEmpty)
        .toList();
    if (!mounted) return;
    final url = await showDialog<String>(
      context: context,
      builder: (_) => _ImportUrlDialog(history: history ?? []),
    );
    if (url == null || url.trim().isEmpty || !mounted) return;
    final trimmed = url.trim();
    // 保存历史记录（逗号分隔，最多 10 条，对标原版 InputDialog history）
    final updated = [
      trimmed,
      ...(history ?? []).where((e) => e != trimmed),
    ].take(10).toList();
    await prefs.setString('rssSourceImportUrls', updated.join(','));
    if (!mounted) return;
    await _fetchFromUrl(trimmed);
  }

  Future<void> _fetchFromUrl(String url) async {
    final l10n = context.l10n;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final api = ref.read(bookApiProvider);
      final response = await bridgeHttpGet(
        api,
        url,
        timeout: const Duration(seconds: 30),
      );
      if (!mounted) return;
      Navigator.of(context).pop(); // 关闭加载指示
      if (!response.isSuccess) {
        _toast(l10n.fetchRssSourcesFailed("HTTP ${response.statusCode}"));
        return;
      }
      await _parseAndConfirm(response.body);
    } catch (e) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      _toast(l10n.fetchRssSourcesFailed(e.toString()));
    }
  }

  /// 二维码导入（对标原版 menu_import_qr）：
  /// HTTP URL → 远程拉取；JSON → 直接解析
  Future<void> _importFromQrCode() async {
    final l10n = context.l10n;
    // [fix Task#24 | 2026-08-08] 去掉 <String> 泛型，避免 routes 表
    // MaterialPageRoute<dynamic> 运行时强转崩溃 — Qoder
    final raw = await Navigator.of(context).pushNamed(AppRoutes.qrcode);
    final content = raw is String ? raw : null;
    if (!mounted) return;
    if (content == null || content.trim().isEmpty) return;
    final trimmed = content.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      await _fetchFromUrl(trimmed);
      return;
    }
    if (trimmed.startsWith('[') || trimmed.startsWith('{')) {
      await _parseAndConfirm(trimmed);
      return;
    }
    _toast(l10n.invalidRssQrCode);
  }

  /// 导入默认规则（对标原版 menu_import_default →
  /// `RssSourceViewModel.importDefault` → `DefaultData.importDefaultRssSources`：
  /// 覆盖 `legado` 分组后灌入 assets 默认源，不经确认对话框）
  Future<void> _importDefault() async {
    final l10n = context.l10n;
    try {
      final n = await syncDefaultRssSources(
        ref.read(rssSourceRepositoryProvider),
      );
      await _load();
      if (!mounted) return;
      _toast(
        n > 0
            ? l10n.importedDefaultRssSourceCount(n)
            : l10n.defaultRssSourcesSynced,
      );
    } catch (e) {
      _toast(l10n.importDefaultRulesFailed(e.toString()));
    }
  }

  /// 帮助页（对标原版 showHelp("SourceMRssHelp")）
  void _showHelpSheet() {
    showHelp(context, HelpAssets.sourceMRssHelp);
  }
}

/// 溢出菜单图标行（对标原版菜单项的 icon + title 结构）
class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MenuRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label)),
      ],
    );
  }
}

/// 网络导入 URL 输入对话框（对标原版 InputDialog：输入框 + 历史记录）
class _ImportUrlDialog extends StatefulWidget {
  final List<String> history;

  const _ImportUrlDialog({required this.history});

  @override
  State<_ImportUrlDialog> createState() => _ImportUrlDialogState();
}

class _ImportUrlDialogState extends State<_ImportUrlDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.importRssSourcesFromUrl),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              autofocus: widget.history.isEmpty,
              decoration: InputDecoration(
                hintText: context.l10n.rssSourceUrlHint,
              ),
              keyboardType: TextInputType.url,
            ),
            if (widget.history.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                context.l10n.history,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 4),
              for (final url in widget.history)
                InkWell(
                  onTap: () => Navigator.pop(context, url),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            final text = _controller.text.trim();
            if (text.isEmpty) return;
            Navigator.pop(context, text);
          },
          child: Text(context.l10n.importAction),
        ),
      ],
    );
  }
}

/// 文本输入对话框（分组名称输入，controller 随子树卸载释放）
class _TextPromptDialog extends StatefulWidget {
  final String title;
  final String hintText;
  final String confirmLabel;
  final bool autofocus;

  const _TextPromptDialog({
    required this.title,
    required this.hintText,
    required this.confirmLabel,
    this.autofocus = false,
  });

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: widget.autofocus,
        decoration: InputDecoration(hintText: widget.hintText),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            final text = _controller.text.trim();
            if (text.isEmpty) return;
            Navigator.pop(context, text);
          },
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
