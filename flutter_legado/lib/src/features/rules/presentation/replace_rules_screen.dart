import '../../../app/routing/app_navigation.dart';
import '../../../widgets/dynamic_search_app_bar.dart';
import '../../../l10n/app_localization.dart';
import '../../../widgets/app_menu.dart';
import '../../../widgets/management_list_card.dart';
import '../../../widgets/app_snack_bar.dart';
import '../../../widgets/confirm_dialog.dart';

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../widgets/md3_fast_scroller.dart';
import '../../../widgets/app_scaffold.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../../../providers/network_provider.dart';

import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/models.dart';
import '../application/replace_rules/replace_rule_notifier.dart';
import '../../../app/routing/route_names.dart';
import '../../../widgets/help/help_assets.dart';
import '../../../widgets/help/show_help.dart';
import '../widgets/replace_rule_group_manage_dialog.dart';
import 'replace_rule_edit_screen.dart';
import 'replace_rule_import_confirm_screen.dart';

/// 替换规则管理页面
class ReplaceRulesScreen extends ConsumerStatefulWidget {
  // [UI-fix v2.0.2 | 2026-08-06] 路由参数：新规则 pattern 预填（阅读器
  // 长按选中文本传入，对标原版 ReplaceEditActivity 预填） — Qoder
  final String? initialPattern;

  const ReplaceRulesScreen({super.key, this.initialPattern});

  @override
  ConsumerState<ReplaceRulesScreen> createState() => _ReplaceRulesScreenState();
}

class _ReplaceRulesScreenState extends ConsumerState<ReplaceRulesScreen> {
  final _searchCtrl = TextEditingController();
  bool _searchExpanded = false;
  String _filter = '';

  // [UI-fix v2.0.2 | 2026-08-06] 分组筛选（对标原版 menu_group：
  // 全部/启用/禁用/无分组/分组:x） — Qoder
  String? _groupFilter;

  // [UI-fix v2.0.2 | 2026-08-06] 批量模式（对标原版 replace_rule_sel.xml：
  // 启用选中/禁用选中/置顶/置底/导出选中） — Qoder
  bool _batchMode = false;
  // [UI_SYNC_REFACTOR R3] 快速滚动条控制器
  final ScrollController _ruleListController = ScrollController();
  final Set<int> _selected = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(replaceRuleNotifierProvider.notifier).load();
      // 路由预填 pattern：首帧后直接打开整页编辑器（pattern 已预填，
      // 对标原版 startIntent pattern 预填；[A3 形态对齐 | full-stack-engineer + UI]）
      final pattern = widget.initialPattern;
      if (mounted && pattern != null && pattern.isNotEmpty) {
        ReplaceRuleEditScreen.open(context, prefillPattern: pattern);
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(replaceRuleNotifierProvider);
    final notifier = ref.read(replaceRuleNotifierProvider.notifier);
    final filtered = _applyFilters(state.rules);
    // [GLOBALCOMP B4] 页壳统一：AppScaffold（行为等价直通 Scaffold）
    return AppScaffold(
      topBar: _batchMode
          ? _buildBatchAppBar()
          : DynamicSearchAppBar(
              title: context.l10n.replaceRules,
              searchController: _searchCtrl,
              searchHint: '搜索规则',
              expanded: _searchExpanded,
              onExpandedChanged: (value) =>
                  setState(() => _searchExpanded = value),
              onChanged: (v) => setState(() => _filter = v.trim()),

              actions: [
                // [UI-fix v2.0.2 | 2026-08-06] 分组筛选入口（对标原版 menu_group）— Qoder
                AppMenuButton<String?>(
                  tooltip: '分组筛选',
                  icon: Icon(
                    _groupFilter == null
                        ? Symbols.filter_list_rounded
                        : Symbols.filter_alt_rounded,
                  ),
                  onSelected: (v) => setState(() => _groupFilter = v),
                  itemBuilder: (_) => [
                    AppMenuItem<String?>(
                      value: null,
                      child: Text(context.l10n.allBooks),
                    ),
                    AppMenuItem<String?>(
                      value: '__enabled__',
                      child: Text(context.l10n.editorEnable),
                    ),
                    AppMenuItem<String?>(
                      value: '__disabled__',
                      child: Text(context.l10n.ruleFilterDisabled),
                    ),
                    AppMenuItem<String?>(
                      value: '__null__',
                      child: Text(context.l10n.ruleNoGroup),
                    ),
                    for (final g in _collectGroups(state.rules))
                      AppMenuItem<String?>(value: g, child: Text('分组：$g')),
                  ],
                ),
                // [UI-fix v2.0.2 | 2026-08-06] 批量模式入口 — Qoder
                IconButton(
                  icon: const Icon(Symbols.checklist_rounded),
                  tooltip: '批量操作',
                  onPressed: () => setState(() => _batchMode = true),
                ),
                // 次要操作统一收入更多菜单，保留三种导入方式。— Codex + UI
                AppMenuButton<String>(
                  tooltip: context.l10n.ruleMoreActions,
                  onSelected: _handleMoreMenu,
                  itemBuilder: (_) => [
                    AppMenuItem(
                      value: 'local',
                      child: Text(context.l10n.importLocal),
                    ),
                    AppMenuItem(
                      value: 'online',
                      child: Text(context.l10n.importOnline),
                    ),
                    AppMenuItem(
                      value: 'qrcode',
                      child: Text(context.l10n.importQrCode),
                    ),
                    const AppMenuDivider(),
                    AppMenuItem(
                      value: 'groups',
                      child: Text(context.l10n.groupManagement),
                    ),
                    AppMenuItem(value: 'help', child: Text(context.l10n.help)),
                  ],
                ),
              ],
            ),
      body: Builder(
        builder: (context) {
          if (state.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.error != null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Symbols.error_rounded,
                    size: 48,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(state.error!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => notifier.load(),
                    child: Text(context.l10n.retry),
                  ),
                ],
              ),
            );
          }
          if (state.rules.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Symbols.find_replace_rounded,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text('暂无替换规则', style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 8),
                  Text(
                    '点击右下角 + 添加规则',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            );
          }
          if (filtered.isEmpty) {
            return Center(
              child: Text(
                '未找到匹配「$_filter」的规则',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            );
          }
          return _buildRuleList(context, notifier, filtered);
        },
      ),
      floatingActionButton: _batchMode
          ? null
          : FloatingActionButton(
              tooltip: context.l10n.ruleNewRule,
              onPressed: () => ReplaceRuleEditScreen.open(context),
              child: const Icon(Symbols.add_rounded),
            ),
    );
  }

  Widget _buildRuleList(
    BuildContext context,
    ReplaceRuleNotifier provider,
    List<ReplaceRule> rules,
  ) {
    // [UI-fix v2.0.2 | 2026-08-06] 批量模式下禁用拖拽排序，行点击切换选中 — Qoder
    if (_batchMode) {
      // [UI_SYNC_REFACTOR R3] 快速滚动条（批量模式长列表）
      return AppScrollBody(
        controller: _ruleListController,
        builder: (context, scrollController) => Md3FastScroller(
          controller: scrollController,
          child: ListView.builder(
            controller: scrollController,
            // 顶部由页壳留白，列表只保留底部8dp与卡片横向间距。
            padding: const EdgeInsets.only(bottom: 8),
            itemCount: rules.length,
            itemBuilder: (context, index) {
              final rule = rules[index];
              return _ReplaceRuleTile(
                key: ValueKey(rule.id),
                rule: rule,
                index: index,
                batchMode: true,
                selected: _selected.contains(rule.id),
                onSelect: () => _toggleSelect(rule.id),
                onToggle: (enabled) => provider.setEnabled(rule.id, enabled),
                onEdit: () => _toggleSelect(rule.id),
                onDelete: () => _confirmDelete(context, provider, rule),
              );
            },
          ),
        ),
      );
    }
    return ReorderableListView.builder(
      // 只从显式手柄拖动，整卡长按仍用于批量选择。— Codex + UI
      buildDefaultDragHandles: false,
      proxyDecorator: ManagementListCard.dragProxy,
      // 为56dp FAB、16dp页边距与16dp内容留白预留尾部空间，末项可滚到按钮上方。
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: rules.length,
      onReorderItem: (oldIndex, newIndex) {
        // 简单的排序处理
        if (oldIndex < newIndex) {
          for (var i = oldIndex; i < newIndex; i++) {
            provider.moveDown(i);
          }
        } else {
          for (var i = oldIndex; i > newIndex; i--) {
            provider.moveUp(i);
          }
        }
      },
      itemBuilder: (context, index) {
        final rule = rules[index];
        return _ReplaceRuleTile(
          key: ValueKey(rule.id),
          rule: rule,
          index: index,
          onToggle: (enabled) => provider.setEnabled(rule.id, enabled),
          // [A3 形态对齐 | full-stack-engineer + UI] 列表行编辑跳整页编辑器
          onEdit: () => ReplaceRuleEditScreen.open(context, rule: rule),
          onDelete: () => _confirmDelete(context, provider, rule),
          onSelect: () => _toggleSelect(rule.id),
          onEnterBatch: () => _enterBatch(rule.id),
        );
      },
    );
  }

  // ===== [UI-fix v2.0.2 | 2026-08-06] 分组筛选 — Qoder =====

  /// P2-12：分组管理弹窗（对标原版 GroupManageDialog）
  Future<void> _showGroupManage(
    BuildContext context,
    List<ReplaceRule> rules,
  ) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => ReplaceRuleGroupManageDialog(rules: rules),
    );
    if (changed == true && mounted) {
      await ref.read(replaceRuleNotifierProvider.notifier).load();
    }
  }

  /// 收集所有分组名（规则的 group 字段可含逗号分隔多分组）
  List<String> _collectGroups(List<ReplaceRule> rules) {
    final groups = <String>{};
    for (final r in rules) {
      final g = r.group;
      if (g == null || g.trim().isEmpty) continue;
      groups.addAll(
        g.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty),
      );
    }
    return groups.toList()..sort();
  }

  /// 分组筛选 + 搜索词叠加过滤（对标原版分组下拉 + view_search）
  List<ReplaceRule> _applyFilters(List<ReplaceRule> rules) {
    Iterable<ReplaceRule> result = rules;
    switch (_groupFilter) {
      case null:
        break;
      case '__enabled__':
        result = result.where((r) => r.isEnabled);
      case '__disabled__':
        result = result.where((r) => !r.isEnabled);
      case '__null__':
        result = result.where(
          (r) => r.group == null || r.group!.trim().isEmpty,
        );
      default:
        final g = _groupFilter!;
        result = result.where(
          (r) => r.group?.split(',').map((e) => e.trim()).contains(g) ?? false,
        );
    }
    if (_filter.isNotEmpty) {
      result = result.where(
        (r) =>
            r.name.contains(_filter) ||
            r.pattern.contains(_filter) ||
            (r.group?.contains(_filter) ?? false),
      );
    }
    return result.toList();
  }

  // ===== [UI-fix v2.0.2 | 2026-08-06] 批量操作（对标 replace_rule_sel.xml）— Qoder =====

  /// 长按进入批量模式并选中该项（对标原版列表长按进入选择态）
  void _enterBatch(int id) {
    setState(() {
      _batchMode = true;
      _selected.add(id);
    });
  }

  void _toggleSelect(int id) {
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  void _exitBatch() {
    setState(() {
      _batchMode = false;
      _selected.clear();
    });
  }

  /// 批量模式顶栏（对标原版 SelectActionBar：关闭 + 已选计数 + 全选）
  PreferredSizeWidget _buildBatchAppBar() {
    return DynamicSearchAppBar(
      title: '已选择 ${_selected.length} 项',
      titleWidget: Text('已选择 ${_selected.length} 项'),
      searchController: _searchCtrl,
      searchHint: '搜索规则',
      expanded: false,
      showSearchAction: false,
      onExpandedChanged: (_) {},
      onChanged: (value) => setState(() => _filter = value.trim()),
      leading: IconButton(
        icon: const Icon(Symbols.close_rounded),
        tooltip: context.l10n.ruleExitBatchMode,
        onPressed: _exitBatch,
      ),
      actions: [
        IconButton(
          icon: const Icon(Symbols.select_all_rounded),
          tooltip: context.l10n.selectAll,
          onPressed: () {
            final state = ref.read(replaceRuleNotifierProvider);
            setState(() {
              _selected.addAll(_applyFilters(state.rules).map((r) => r.id));
            });
          },
        ),
        AppMenuButton<String>(
          tooltip: '批量操作',
          onSelected: _handleBatchAction,
          itemBuilder: (_) => [
            AppMenuItem(
              value: 'enable',
              child: Text(context.l10n.enableSelected),
            ),
            AppMenuItem(
              value: 'disable',
              child: Text(context.l10n.disableSelected),
            ),
            AppMenuItem(value: 'top', child: Text(context.l10n.pinToTop)),
            AppMenuItem(
              value: 'bottom',
              child: Text(context.l10n.moveToBottom),
            ),
            AppMenuItem(
              value: 'export',
              child: Text(context.l10n.exportSelected),
            ),
          ],
        ),
      ],
    );
  }

  /// 批量操作分发（5 项：启用选中/禁用选中/置顶/置底/导出选中）
  Future<void> _handleBatchAction(String action) async {
    if (_selected.isEmpty) return;
    final notifier = ref.read(replaceRuleNotifierProvider.notifier);
    final ids = _selected.toList();
    switch (action) {
      case 'enable':
      case 'disable':
        for (final id in ids) {
          await notifier.setEnabled(id, action == 'enable');
        }
        _exitBatch();
      case 'top':
        await notifier.moveToTop(ids);
        _exitBatch();
      case 'bottom':
        await notifier.moveToBottom(ids);
        _exitBatch();
      case 'export':
        await _exportSelected(ids);
    }
  }

  /// 导出选中规则（对标原版 menu_export_selection：JSON 分享）
  Future<void> _exportSelected(List<int> ids) async {
    final rules = ref
        .read(replaceRuleNotifierProvider)
        .rules
        .where((r) => ids.contains(r.id))
        .toList();
    if (rules.isEmpty) return;
    final json = const JsonEncoder.withIndent('  ')
        .convert(rules.map((r) => r.toJson()).toList());
    try {
      await SharePlus.instance.share(
        ShareParams(text: json, subject: 'Legado 替换规则'),
      );
      if (mounted) _exitBatch();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('导出失败：$e')));
      }
    }
  }

  /// 更多菜单复用既有导入、分组管理及帮助入口。— Codex + UI
  void _handleMoreMenu(String value) {
    switch (value) {
      case 'local':
        _importFromFile();
      case 'online':
        _showImportUrlDialog();
      case 'qrcode':
        _importFromQrCode();
      case 'groups':
        _showGroupManage(context, ref.read(replaceRuleNotifierProvider).rules);
      case 'help':
        showHelp(context, HelpAssets.replaceRuleHelp);
    }
  }

  /// 网络导入弹窗（对标原版 showImportDialog：URL 输入 + 历史记录）
  Future<void> _showImportUrlDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs
        .getString('replaceRuleImportUrls')
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
    await prefs.setString('replaceRuleImportUrls', updated.join(','));
    if (!mounted) return;
    await _fetchFromUrl(trimmed);
  }

  /// 从 URL 拉取规则文本后进入导入确认页
  Future<void> _fetchFromUrl(String url) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final network = ref.read(networkServiceProvider);
      final response = await network.httpGet(
        url,
        timeout: const Duration(seconds: 30),
      );
      if (!mounted) return;
      Navigator.of(context).pop(); // 关闭加载指示
      if (!response.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('获取替换规则失败：HTTP ${response.statusCode}')),
        );
        return;
      }
      await _parseAndConfirm(response.body);
    } catch (e) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('获取替换规则失败：$e')));
      }
    }
  }

  /// 二维码导入（对标原版 menu_import_qr）：
  /// HTTP URL → 远程拉取；JSON → 直接解析
  Future<void> _importFromQrCode() async {
    // [fix Task#24 | 2026-08-08] 去掉 <String> 泛型，避免 routes 表
    // MaterialPageRoute<dynamic> 运行时强转崩溃 — Qoder
    final raw = await GoRouter.of(context).pushAppRoute(AppRoutes.qrcode);
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
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('扫码内容不是可识别的替换规则数据')));
  }

  /// 本地文件导入（对标原版 menu_import_local：任选文件，解析层容错）
  ///
  /// 注：与书源/RSS 导入同策略，不使用扩展名过滤（低版本 Android SAF
  /// MIME 匹配问题），解析失败由提示兜底。
  Future<void> _importFromFile() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picked = await FilePicker.pickFile();
      if (picked == null) return;
      final path = picked.path;
      if (path == null) {
        messenger.showSnackBar(const SnackBar(content: Text('无法获取文件路径')));
        return;
      }
      final text = await File(path).readAsString();
      if (!mounted) return;
      await _parseAndConfirm(text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('从文件导入失败：$e')));
      }
    }
  }

  /// 解析替换规则文本（对标原版 ImportReplaceRuleDialog 容错：
  /// 数组 / {"replaceRules": [...]} / 单对象均可）
  List<Map<String, dynamic>> _parseRulesText(String text) {
    final decoded = jsonDecode(text.trim());
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (decoded is Map) {
      final list = decoded['replaceRules'];
      if (list is List) {
        return list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [Map<String, dynamic>.from(decoded)];
    }
    throw const FormatException('格式错误，未解析到替换规则');
  }

  /// 候选规则 → 导入确认页（对标原版 comparisonSource 流程：
  /// 用户勾选确认后才入库）
  Future<void> _parseAndConfirm(String text) async {
    List<Map<String, dynamic>> candidates;
    try {
      candidates = _parseRulesText(text);
    } catch (_) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('格式错误，未解析到替换规则')));
      return;
    }
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('格式错误，未解析到替换规则')));
      return;
    }
    if (!mounted) return;
    final localRules = ref.read(replaceRuleNotifierProvider).rules;
    final imported = await ReplaceRuleImportConfirmScreen.open(
      context,
      raws: candidates,
      localRules: localRules,
    );
    if (!mounted) return;
    // 确认页返回导入成功条数；取消返回 null/0
    if (imported != null && imported > 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('导入完成（$imported 条）')));
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    ReplaceRuleNotifier provider,
    ReplaceRule rule,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.deleteReplaceRuleTitle,
      content: l10n.confirmDeleteNamedRule(rule.name),
      confirmText: l10n.delete,
      isDestructive: true,
    );
    if (!confirmed || !context.mounted) return;
    try {
      await provider.deleteRule(rule.id);
      if (context.mounted) showAppSnackBar(context, l10n.ruleDeleted);
    } catch (error) {
      if (context.mounted) {
        showAppSnackBar(context, l10n.ruleDeleteFailed(error.toString()));
      }
    }
  }
}

class _ReplaceRuleTile extends StatelessWidget {
  final ReplaceRule rule;
  final int index;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit, onDelete, onSelect;
  final VoidCallback? onEnterBatch;
  final bool batchMode, selected;

  const _ReplaceRuleTile({
    super.key,
    required this.rule,
    required this.index,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onSelect,
    this.onEnterBatch,
    this.batchMode = false,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ManagementListCard(
      dragIndex: batchMode ? null : index,
      batchMode: batchMode,
      selected: selected,
      isEnabled: rule.isEnabled,
      onEnabledChanged: onToggle,
      onEdit: onEdit,
      onSelect: onSelect,
      onLongPress: batchMode ? onSelect : onEnterBatch,
      information: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rule.name.isEmpty ? '(未命名)' : rule.name,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 2),
          Text(
            '${rule.isRegex ? context.l10n.searchUseRegex : context.l10n.editorText}: ${rule.pattern} → ${rule.replacement}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (rule.scope != null && rule.scope!.isNotEmpty)
            Text(
              '范围: ${rule.scope}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.secondary,
              ),
            ),
        ],
      ),
      menu: batchMode
          ? null
          : AppMenuButton<String>(
              icon: Icon(
                Symbols.more_vert_rounded,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              tooltip: context.l10n.more,
              onSelected: (value) {
                if (value == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                AppMenuItem(value: 'delete', child: Text(context.l10n.delete)),
              ],
            ),
    );
  }
}

/// [UI-fix v2.0.2 | 2026-08-06] 网络导入 URL 输入对话框
///（对标原版 InputDialog：输入框 + 历史记录） — Qoder
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
      title: const Text('从 URL 导入替换规则'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              autofocus: widget.history.isEmpty,
              decoration: const InputDecoration(hintText: '输入替换规则 URL 地址'),
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
            final url = _controller.text.trim();
            if (url.isEmpty) return;
            Navigator.pop(context, url);
          },
          child: Text(context.l10n.importAction),
        ),
      ],
    );
  }
}
