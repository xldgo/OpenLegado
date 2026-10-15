import '../l10n/app_localization.dart';
import '../widgets/app_menu.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:material_symbols_icons/symbols.dart';

import '../bridge/ffi.dart';
import '../data/defaults/dict_rule_defaults.dart';
import '../models/misc.dart' show DictRule;
import '../providers/dictionary_provider.dart';
import '../routes.dart' show AppRoutes;
import '../widgets/empty_state.dart';
import '../widgets/error_view.dart';
import '../widgets/help/help_assets.dart';
import '../widgets/help/show_help.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/legado_app_bar.dart';
import '../widgets/loading_indicator.dart';

/// 字典规则管理页
///
/// [C2 批2 | full-stack-engineer + UI] 对齐原版
/// `DictRuleActivity`（app/src/main/java/io/legado/app/ui/dict/rule/）
/// 行形态与操作，使用DictRuleRepository七项配置访问（契约 §2.45）：
/// dictRuleList / dictRuleAdd / dictRuleUpdate / dictRuleDelete /
/// dictRuleSetEnabled / dictRuleReorder / dictRuleImport。
///
/// 与原版对齐点：
/// - 行 = 规则名 + 启用 Switch（swtEnabled）+ 行级编辑/删除（ivEdit/ivDelete）；
///   本批按任务口径收敛为：名称 + Switch + 副行 urlRule 截断，行点按打开
///   三字段编辑弹层（对标 DictRuleEditDialog 的 name/urlRule/showRule）；
/// - 长按进入多选（对标 DragSelectTouchHelper.activeSlideSelect 长按即多选）：
///   批量启用/禁用/删除（对标 SelectActionBar menu_enable_selection /
///   menu_disable_selection / 主操作 delete，删除带确认框对标原版 alert）；
/// - 拖拽排序（对标 ItemTouchCallback + upSortNumber）→ dictRuleReorder；
/// - 菜单 = 新增 / 本地导入 / 扫码导入 / 在线导入 / 导入默认 / 帮助
///   （对标 R.menu.dict_rule：menu_add / menu_import_local /
///   menu_import_qr / menu_import_onLine / menu_import_default /
///   menu_help）；
///   menu_import_qr（扫码导入）复用既有 QrcodeScreen 扫码链路
///   （routes 表 AppRoutes.qrcode，移动端相机 / 桌面与测试降级手动输入），
///   扫码原始内容按 kind='text' 走 dictRuleImport（与本地导入同语义）；
/// - 「导入默认」：原版走 assets/defaultData/dictRules.json 的
///   importDefaultDictRules（按 name REPLACE 写入 5 默认源）；本批以
///   dictRuleImport(kind:'text', payload=内置 dictRules.json) 实现同语义
///   （空表 seed 由 dictRuleList 侧自动完成，导入为显式恢复动作）。
///
/// 列表、查询和导入共用DictRuleRepository与共享实体。
class DictRuleScreen extends ConsumerStatefulWidget {
  const DictRuleScreen({super.key});

  @override
  ConsumerState<DictRuleScreen> createState() => _DictRuleScreenState();
}

class _DictRuleScreenState extends ConsumerState<DictRuleScreen> {
  // ========== 列表状态 ==========
  List<DictRule> _rows = const [];
  bool _loading = true;
  String? _error;
  bool _busy = false;

  // ========== 多选状态（对标原版 SelectActionBar） ==========
  bool _selectMode = false;
  final Set<int> _selectedIds = {};

  /// 错误信息归一（BridgeError 取 message，其余 toString）
  String _errMsg(Object e) => e is BridgeError ? e.message : e.toString();

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// 加载全部字典规则（dictRuleList，ORDER BY sortNumber, id）
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await ref.read(dictRuleRepositoryProvider).dictRuleList();
      if (!mounted) return;
      setState(() {
        _rows = raw;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _errMsg(e);
        _loading = false;
      });
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // ========== 启停（对标 swtEnabled.setOnUserCheckedChangeListener） ==========

  Future<void> _toggleEnabled(DictRule row, bool value) async {
    if (_busy) return;
    setState(() => _busy = true);
    final updated = row.copyWith(enabled: value);
    // 乐观更新，失败回滚并上报
    final previous = _rows;
    final next = [..._rows]..[_rows.indexOf(row)] = updated;
    _rows = next;
    setState(() {});
    try {
      final changed = await ref
          .read(dictRuleRepositoryProvider)
          .dictRuleSetEnabled(id: row.id, enabled: value);
      if (!changed) throw StateError('规则不存在或未更新');
    } catch (e) {
      _rows = previous;
      setState(() {});
      _snack('启用/禁用失败：${_errMsg(e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ========== 拖拽排序（对标 ItemTouchCallback + upSortNumber） ==========

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (_selectMode || _busy) return;
    final list = [..._rows];
    final moved = list.removeAt(oldIndex);
    list.insert(newIndex, moved);
    // 本地先行换位（对标原版 swap 先交换 UI 再落库），落库失败回滚
    final previous = _rows;
    setState(() {
      _rows = list;
      _busy = true;
    });
    try {
      final changed = await ref
          .read(dictRuleRepositoryProvider)
          .dictRuleReorder(list.map((r) => r.id).toList());
      if (changed != list.length) throw StateError('规则排序未完整保存');
      // 对标 upSortNumber 重编号语义：本地 sortNumber 同步为 0..n-1
      setState(() {
        for (var i = 0; i < _rows.length; i++) {
          _rows[i] = _rows[i].copyWith(sortNumber: i);
        }
      });
    } catch (e) {
      setState(() => _rows = previous);
      _snack('排序保存失败：${_errMsg(e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ========== 多选（对标 DragSelectTouchHelper 长按进入选择） ==========

  void _enterSelectMode(int id) {
    setState(() {
      _selectMode = true;
      _selectedIds
        ..clear()
        ..add(id);
    });
  }

  void _toggleSelect(int id) {
    setState(() {
      if (!_selectedIds.remove(id)) _selectedIds.add(id);
    });
  }

  void _selectToggleAll() {
    setState(() {
      if (_selectedIds.length == _rows.length && _rows.isNotEmpty) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(_rows.map((r) => r.id));
      }
    });
  }

  void _exitSelectMode() {
    setState(() {
      _selectMode = false;
      _selectedIds.clear();
    });
  }

  /// 批量启用/禁用（对标 menu_enable_selection / menu_disable_selection，
  /// 原版经 DictRuleDao upsert enabled；本批经 dictRuleSetEnabled 逐条落库）
  Future<void> _batchSetEnabled(bool enabled) async {
    if (_busy || _selectedIds.isEmpty) return;
    setState(() => _busy = true);
    final ids = _selectedIds.toList();
    final targets = _rows.where((r) => _selectedIds.contains(r.id)).toList();
    try {
      final api = ref.read(dictRuleRepositoryProvider);
      for (final row in targets) {
        final changed = await api.dictRuleSetEnabled(
          id: row.id,
          enabled: enabled,
        );
        if (!changed) throw StateError('规则不存在或未更新');
      }
      setState(() {
        for (var i = 0; i < _rows.length; i++) {
          if (_selectedIds.contains(_rows[i].id)) {
            _rows[i] = _rows[i].copyWith(enabled: enabled);
          }
        }
        _exitSelectMode();
      });
      _snack('已${enabled ? '启用' : '禁用'} ${ids.length} 条规则');
    } catch (e) {
      _snack('批量${enabled ? '启用' : '禁用'}失败：${_errMsg(e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 批量删除（对标 SelectActionBar 主操作 delete；删除需确认框，
  /// 对标原版 alert(R.string.sure_del) + rule.name）
  Future<void> _batchDelete() async {
    if (_busy || _selectedIds.isEmpty) return;
    final targets = _rows.where((r) => _selectedIds.contains(r.id)).toList();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除规则'),
        content: SizedBox(
          width: double.maxFinite,
          child: Text(
            '确定删除选中的 ${targets.length} 条字典规则吗？\n'
            '（${targets.map((r) => r.name).join('、')}）',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      final api = ref.read(dictRuleRepositoryProvider);
      for (final row in targets) {
        final removed = await api.dictRuleDelete(row.id);
        if (!removed) throw StateError('规则不存在或未删除');
      }
      setState(() {
        _rows.removeWhere((r) => _selectedIds.contains(r.id));
        _exitSelectMode();
      });
      _snack('已删除 ${targets.length} 条规则');
    } catch (e) {
      _snack('删除失败：${_errMsg(e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ========== 编辑弹层（对标 DictRuleEditDialog 三字段） ==========

  Future<void> _showRuleEditor({DictRule? row}) async {
    // 控制器由弹层 State 持有并在其 dispose 释放（退出动画期间父层
    // setState 重建不得触碰已释放控制器）
    await showDialog<void>(
      context: context,
      builder: (ctx) => _RuleEditDialog(
        title: row == null ? '添加字典规则' : '编辑字典规则',
        initialName: row?.name ?? '',
        initialUrl: row == null
            ? 'https://example.com/dict?q={{key}}'
            : row.urlRule,
        initialShow: row?.showRule ?? '',
        onSaved: (name, urlRule, showRule) => _saveRule(
          row: row,
          name: name,
          urlRule: urlRule,
          showRule: showRule,
        ),
      ),
    );
  }

  Future<void> _saveRule({
    DictRule? row,
    required String name,
    required String urlRule,
    required String showRule,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final api = ref.read(dictRuleRepositoryProvider);
      if (row == null) {
        final id = await api.dictRuleAdd(
          name: name,
          urlRule: urlRule,
          showRule: showRule,
        );
        if (id <= 0) throw StateError('新增规则未返回有效主键');
      } else {
        final changed = await api.dictRuleUpdate(
          id: row.id,
          name: name,
          urlRule: urlRule,
          showRule: showRule,
        );
        if (!changed) throw StateError('规则不存在或未更新');
      }
      // 新增的 sortNumber/id 以服务端为准，直接重载保证顺序与主键一致
      await _load();
      _snack(row == null ? '已添加规则「$name」' : '已更新规则「$name」');
    } catch (e) {
      _snack('保存失败：${_errMsg(e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ========== 菜单操作（对标 R.menu.dict_rule） ==========

  void _onMenuSelected(String value) {
    switch (value) {
      case 'add':
        _showRuleEditor();
      case 'importLocal':
        _showImportLocalDialog();
      case 'importQr':
        _importFromQr();
      case 'importOnline':
        _showImportOnlineDialog();
      case 'importDefault':
        _importDefaultRules();
      case 'help':
        showHelp(context, HelpAssets.dictRuleHelp);
    }
  }

  /// 本地导入（对标 menu_import_local：原版选 .txt/.json 文件，
  /// 本批以粘贴 JSON 文本等价承接，kind='text'）
  Future<void> _showImportLocalDialog() async {
    String? text;
    await showDialog<String>(
      context: context,
      builder: (ctx) => _ImportTextDialog(
        title: ctx.l10n.importLocal,
        hint:
            '粘贴 JSON（对象数组或单对象，字段 name/urlRule/showRule，'
            'enabled/sortNumber 可选）',
        onImport: (value) => text = value,
      ),
    );
    final payload = text ?? '';
    if (payload.isEmpty) return;
    setState(() => _busy = true);
    try {
      final n = await ref
          .read(dictRuleRepositoryProvider)
          .dictRuleImport(jsonOrUrl: payload, kind: 'text');
      await _load();
      _snack('已导入 $n 条字典规则');
    } catch (e) {
      _snack('导入失败：${_errMsg(e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 扫码导入（对标 menu_import_qr：原版扫码/粘贴内容后走本地导入同链路）
  ///
  /// 复用既有 QrcodeScreen（routes 表 AppRoutes.qrcode：移动端相机实时扫码，
  /// 桌面端/测试环境降级手动输入），扫码原始内容按 kind='text' 走
  /// dictRuleImport，与本地导入（粘贴 JSON 文本）同语义；
  /// 取消（pop null）或空内容仅提示不导入。
  Future<void> _importFromQr() async {
    final navigator = Navigator.of(context);
    final raw = await navigator.pushNamed(AppRoutes.qrcode);
    final payload = raw is String ? raw.trim() : '';
    if (!mounted) return;
    if (payload.isEmpty) {
      _snack('未获取到扫码内容');
      return;
    }
    setState(() => _busy = true);
    try {
      final n = await ref
          .read(dictRuleRepositoryProvider)
          .dictRuleImport(jsonOrUrl: payload, kind: 'text');
      await _load();
      _snack('已导入 $n 条字典规则');
    } catch (e) {
      _snack('导入失败：${_errMsg(e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 在线导入（对标 menu_import_onLine → ImportDictRuleDialog(url)，
  /// kind='url' 经既有抓取链路取 body 再解析）
  Future<void> _showImportOnlineDialog() async {
    String? text;
    await showDialog<String>(
      context: context,
      builder: (ctx) => _ImportTextDialog(
        title: ctx.l10n.ruleImportOnline,
        hint: 'https://example.com/dictRules.json',
        isUrl: true,
        onImport: (value) => text = value,
      ),
    );
    final value = text;
    if (value == null) return;
    // text 被闭包写入不可提升，经 value 提升为非空 String
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      _snack('请输入有效的 http(s) 地址');
      return;
    }
    setState(() => _busy = true);
    try {
      final n = await ref
          .read(dictRuleRepositoryProvider)
          .dictRuleImport(jsonOrUrl: value, kind: 'url');
      await _load();
      _snack('已导入 $n 条字典规则');
    } catch (e) {
      _snack('导入失败：${_errMsg(e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 导入默认（对标 menu_import_default → importDefaultDictRules：
  /// 按 name REPLACE 写回原版 5 默认源；payload 取内置 dictRules.json，
  /// 与 dictRuleList 空表 seed 同源）
  Future<void> _importDefaultRules() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final n = await importDefaultDictRules(
        ref.read(dictRuleRepositoryProvider),
      );
      await _load();
      _snack('已导入 $n 条默认字典规则');
    } catch (e) {
      _snack('导入默认失败：${_errMsg(e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ========== 构建 ==========

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // [GLOBALCOMP B4] 页壳统一：AppScaffold（行为等价直通 Scaffold）
    return AppScaffold(
      topBar: _selectMode ? _buildSelectAppBar() : _buildNormalAppBar(),
      body: _buildBody(theme),
      floatingActionButton: _selectMode
          ? null
          : FloatingActionButton.extended(
              // 对标原版 FAB 新增（menu_add 同语义：DictRuleEditDialog 空表单）
              onPressed: _busy ? null : () => _showRuleEditor(),
              icon: const Icon(Symbols.add_rounded),
              label: Text(context.l10n.ruleNewRule),
            ),
    );
  }

  PreferredSizeWidget _buildNormalAppBar() {
    return LegadoAppBar(
      title: Text(context.l10n.dictionaryRuleManagement),
      actions: [
        // 对标 R.menu.dict_rule（menu_add/menu_import_local/menu_import_qr/
        // menu_import_onLine/menu_import_default/menu_help；
        // menu_import_qr 复用 QrcodeScreen 扫码链路，见 _importFromQr）
        AppMenuButton<String>(
          tooltip: context.l10n.ruleMoreActions,
          icon: const Icon(Symbols.more_vert_rounded),
          onSelected: _onMenuSelected,
          itemBuilder: (_) => [
            AppMenuItem(value: 'add', child: Text(context.l10n.ruleNewRule)),
            AppMenuItem(
              value: 'importLocal',
              child: Text(context.l10n.importLocal),
            ),
            AppMenuItem(value: 'importQr', child: Text('扫码导入')),
            AppMenuItem(
              value: 'importOnline',
              child: Text(context.l10n.ruleImportOnline),
            ),
            AppMenuItem(
              value: 'importDefault',
              child: Text(context.l10n.ruleImportDefault),
            ),
            AppMenuItem(value: 'help', child: Text(context.l10n.help)),
          ],
        ),
      ],
    );
  }

  /// 多选模式顶栏（对标 SelectActionBar：计数 + 启用选中/禁用选中/删除）
  PreferredSizeWidget _buildSelectAppBar() {
    final allSelected = _rows.isNotEmpty && _selectedIds.length == _rows.length;
    return LegadoAppBar(
      title: Text('已选 ${_selectedIds.length} 项'),
      leading: IconButton(
        icon: const Icon(Symbols.close_rounded),
        tooltip: context.l10n.ruleExitSelection,
        onPressed: _exitSelectMode,
      ),
      actions: [
        TextButton(
          onPressed: _selectToggleAll,
          child: Text(
            allSelected ? context.l10n.ruleDeselectAll : context.l10n.selectAll,
          ),
        ),
        IconButton(
          icon: const Icon(Symbols.check_circle_outline_rounded),
          tooltip: context.l10n.enableSelected,
          onPressed: _busy ? null : () => _batchSetEnabled(true),
        ),
        IconButton(
          icon: const Icon(Symbols.remove_circle_outline_rounded),
          tooltip: context.l10n.disableSelected,
          onPressed: _busy ? null : () => _batchSetEnabled(false),
        ),
        IconButton(
          icon: const Icon(Symbols.delete_rounded),
          tooltip: context.l10n.ruleDeleteSelected,
          onPressed: _busy ? null : _batchDelete,
        ),
      ],
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return const LoadingIndicator(message: '加载字典规则...');
    }
    if (_error != null) {
      return ErrorView(message: _error!, onRetry: _load);
    }
    if (_rows.isEmpty) {
      return EmptyState(
        icon: Symbols.rule_folder_rounded,
        title: '暂无字典规则',
        subtitle: '点击右下角按钮添加，或从右上角菜单导入',
        action: FilledButton(
          onPressed: _busy ? null : () => _showRuleEditor(),
          child: Text(context.l10n.ruleNewRule),
        ),
      );
    }
    return ReorderableListView.builder(
      // [LAYOUT_PLAN P2] 列表横向由卡片 margin 统一 16dp，纵向留白 8dp
      // Flutter 3.44 起 onReorderItem 必须恒提供（二选一断言），
      // 多选/忙碌态由 _onReorder 内部守卫短路
      padding: const EdgeInsets.symmetric(vertical: 8),
      buildDefaultDragHandles: false,
      itemCount: _rows.length,
      onReorderItem: _onReorder,
      itemBuilder: (context, index) => _buildRow(theme, index),
    );
  }

  Widget _buildRow(ThemeData theme, int index) {
    final row = _rows[index];
    final cs = theme.colorScheme;
    final textTheme = theme.textTheme;
    final selected = _selectedIds.contains(row.id);
    return Card(
      key: ValueKey(index),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: selected ? cs.primaryContainer : cs.surfaceContainer,
      child: ListTile(
        shape: const RoundedRectangleBorder(),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 16,
        ),
        leading: _selectMode
            ? Checkbox(
                value: selected,
                onChanged: (_) => _toggleSelect(row.id),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              )
            : ReorderableDragStartListener(
                index: index,
                child: Icon(Symbols.drag_indicator_rounded, color: cs.outline),
              ),
        title: Text(
          row.name,
          style: textTheme.titleMedium?.copyWith(
            // 禁用规则降透明度（对标原版行内 switch 关态视觉弱化）
            color: row.enabled
                ? null
                : cs.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
        subtitle: Text(
          row.urlRule.isEmpty ? '（未配置查询地址）' : row.urlRule,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        trailing: Switch(
          value: row.enabled,
          onChanged: _busy ? null : (v) => _toggleEnabled(row, v),
        ),
        onTap: () {
          if (_selectMode) {
            _toggleSelect(row.id);
          } else {
            _showRuleEditor(row: row);
          }
        },
        onLongPress: () => _enterSelectMode(row.id),
      ),
    );
  }
}

/// 规则编辑弹层（对标 DictRuleEditDialog 三字段：tvRuleName/tvUrlRule/tvShowRule；
/// 规则名必填校验，urlRule/showRule 支持多行长文本）
///
/// 控制器由本 State 持有并在 [dispose] 释放；保存成功先 pop 再回调
/// [onSaved]（此时三字段已 trim，回调方无需再触碰控制器）。
typedef _RuleSavedCallback = void Function(
  String name,
  String urlRule,
  String showRule,
);

class _RuleEditDialog extends StatefulWidget {
  const _RuleEditDialog({
    required this.title,
    required this.initialName,
    required this.initialUrl,
    required this.initialShow,
    required this.onSaved,
  });

  final String title;
  final String initialName;
  final String initialUrl;
  final String initialShow;
  final _RuleSavedCallback onSaved;

  @override
  State<_RuleEditDialog> createState() => _RuleEditDialogState();
}

class _RuleEditDialogState extends State<_RuleEditDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _urlCtrl;
  late final TextEditingController _showCtrl;
  bool _nameInvalid = false;
  final _nameFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _urlCtrl = TextEditingController(text: widget.initialUrl);
    _showCtrl = TextEditingController(text: widget.initialShow);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _urlCtrl.dispose();
    _showCtrl.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameCtrl,
                focusNode: _nameFocus,
                autofocus: true,
                // [LAYOUT_PLAN P2] 输入框走 inputDecorationTheme（不显式 border）
                decoration: InputDecoration(
                  labelText: context.l10n.ruleName,
                  errorText: _nameInvalid ? '规则名称不能为空' : null,
                ),
                onChanged: (_) => setState(
                  () => _nameInvalid = _nameCtrl.text.trim().isEmpty,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _urlCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '查询地址（urlRule）',
                  hintText: 'https://example.com/dict?q={{key}}',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _showCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: '显示规则（showRule，可选）',
                  hintText: 'CSS/XPath/JsonPath 或 @js: 规则，留空直接展示原文',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            if (_nameCtrl.text.trim().isEmpty) {
              setState(() => _nameInvalid = true);
              _nameFocus.requestFocus();
              return;
            }
            final name = _nameCtrl.text.trim();
            final urlRule = _urlCtrl.text.trim();
            final showRule = _showCtrl.text.trim();
            Navigator.of(context).pop();
            widget.onSaved(name, urlRule, showRule);
          },
          child: Text(context.l10n.save),
        ),
      ],
    );
  }
}

/// 导入文本弹层（本地导入 = JSON 文本多行；在线导入 = URL 单行）
///
/// 控制器由本 State 持有并在 [dispose] 释放；点「导入」先 pop 再以
/// trim 后文本回调 [onImport]（取消不回调）。
class _ImportTextDialog extends StatefulWidget {
  const _ImportTextDialog({
    required this.title,
    required this.hint,
    this.isUrl = false,
    required this.onImport,
  });

  final String title;
  final String hint;
  final bool isUrl;
  final ValueChanged<String> onImport;

  @override
  State<_ImportTextDialog> createState() => _ImportTextDialogState();
}

class _ImportTextDialogState extends State<_ImportTextDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: double.maxFinite,
        child: TextField(
          controller: _ctrl,
          autofocus: true,
          maxLines: widget.isUrl ? 1 : 6,
          textInputAction: widget.isUrl ? TextInputAction.done : null,
          decoration: InputDecoration(
            hintText: widget.hint,
            alignLabelWithHint: true,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            final value = _ctrl.text.trim();
            Navigator.of(context).pop(value);
            widget.onImport(value);
          },
          child: Text(context.l10n.importAction),
        ),
      ],
    );
  }
}
