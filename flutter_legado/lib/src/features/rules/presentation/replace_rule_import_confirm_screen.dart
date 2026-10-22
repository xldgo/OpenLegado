import '../../../providers/replace_rule_repository_provider.dart';
import '../../../widgets/app_menu.dart';

import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import '../../../widgets/import_confirm_scaffold.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../../../models/models.dart';
import '../application/replace_rules/replace_rule_notifier.dart';
import '../../../widgets/custom_group_dialog.dart';

/// 替换规则导入确认页（对标原版 ImportReplaceRuleDialog）
///
/// 拉取/解析出的候选替换规则在此页供用户勾选确认后才写入数据库：
/// - 列表项：勾选框 + 名称(分组) + 新增/更新/已有 状态 + 打开（查看 JSON）
/// - 顶部菜单：自定义源分组 / 保留原名（对标 import_replace.xml；
///   原版保留原名仅持久化偏好，不在导入时应用）
/// - 底部：全选|取消全选（n/m）/ 取消 / 确认
/// - 确认后返回导入成功条数
class ReplaceRuleImportConfirmScreen extends ConsumerStatefulWidget {
  /// 候选替换规则原始 JSON 列表（保留原始 Map，未入库）
  final List<Map<String, dynamic>> raws;

  /// 本地现有替换规则（按 id 匹配做状态判定，对标
  /// compareImportedReplaceRules 的 findByIds）
  final List<ReplaceRule> localRules;

  /// 共用打开方式，保留本页参数和返回值语义。— Codex + UI
  static Future<int?> open(
    BuildContext context, {
    required List<Map<String, dynamic>> raws,
    required List<ReplaceRule> localRules,
  }) => Navigator.of(context).push<int>(
    MaterialPageRoute<int>(
      builder: (_) =>
          ReplaceRuleImportConfirmScreen(raws: raws, localRules: localRules),
    ),
  );

  const ReplaceRuleImportConfirmScreen({
    super.key,
    required this.raws,
    required this.localRules,
  });

  @override
  ConsumerState<ReplaceRuleImportConfirmScreen> createState() =>
      _ReplaceRuleImportConfirmScreenState();
}

class _ReplaceRuleImportConfirmScreenState
    extends ConsumerState<ReplaceRuleImportConfirmScreen> {
  late final Map<int, ReplaceRule> _localById = {
    for (final r in widget.localRules) r.id: r,
  };

  /// 候选规则类型化视图（单条解析失败为 null，勾选时跳过）
  late final List<ReplaceRule?> _parsed = [
    for (final raw in widget.raws) _parse(raw),
  ];

  late final List<bool> _selected = [
    // 原版默认选中策略（compareImportedReplaceRules）：
    // 本地无同 id 规则（新增）才默认选中
    for (final rule in _parsed) rule != null && _localById[rule.id] == null,
  ];

  // 菜单选项（对标 import_replace.xml：仅自定义分组 + 保留原名）
  bool _keepName = false;

  // 自定义源分组
  String? _groupName;
  bool _isAddGroup = false;

  bool _importing = false;

  ReplaceRule? _parse(Map<String, dynamic> raw) {
    try {
      return ReplaceRule.fromJson(raw);
    } catch (_) {
      // 单条解析失败容错（对标 ReplaceAnalyzer 逐条失败不中断）
      return null;
    }
  }

  ImportCandidateStatus _statusOf(int index) {
    final rule = _parsed[index];
    if (rule == null) return ImportCandidateStatus.isNew;
    final local = _localById[rule.id];
    if (local == null) return ImportCandidateStatus.isNew;
    if (rule.pattern != local.pattern ||
        rule.replacement != local.replacement ||
        rule.isRegex != local.isRegex ||
        rule.scope != local.scope) {
      return ImportCandidateStatus.isUpdate;
    }
    return ImportCandidateStatus.exists;
  }

  /// 列表项名称（对标原版：group 非空时显示「名称(分组)」）
  String _displayName(int index) {
    final rule = _parsed[index];
    if (rule == null) return '(格式错误)';
    final group = rule.group?.trim() ?? '';
    return group.isEmpty ? rule.name : '${rule.name}($group)';
  }

  int get _selectCount {
    var count = 0;
    for (final b in _selected) {
      if (b) count++;
    }
    return count;
  }

  bool get _isSelectAll => _selected.every((b) => b);

  /// 确认导入：应用自定义分组后按 id 匹配入库
  /// （对标 ImportReplaceRuleViewModel.importSelect：
  /// Room insert 按主键 upsert → 本地同 id 走更新，否则新增）
  Future<void> _confirmImport() async {
    if (_selectCount == 0) return;
    setState(() => _importing = true);
    try {
      final group = _groupName?.trim();
      var success = 0;
      for (var i = 0; i < widget.raws.length; i++) {
        if (!_selected[i]) continue;
        final rule = _parsed[i];
        if (rule == null) continue;
        var target = rule;
        if (group != null && group.isNotEmpty) {
          if (_isAddGroup) {
            final groups = <String>{
              ...?rule.group
                  ?.split(',')
                  .map((g) => g.trim())
                  .where((g) => g.isNotEmpty),
              group,
            };
            target = target.copyWith(group: groups.join(','));
          } else {
            target = target.copyWith(group: group);
          }
        }
        try {
          if (_localById.containsKey(target.id)) {
            await ref
                .read(replaceRuleRepositoryProvider)
                .updateReplaceRule(target);
          } else {
            await ref
                .read(replaceRuleRepositoryProvider)
                .addReplaceRule(target);
          }
          success++;
        } catch (_) {
          // 单条入库失败跳过（对标原版逐条容错）
        }
      }
      await ref.read(replaceRuleNotifierProvider.notifier).load();
      if (mounted) Navigator.of(context).pop(success);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('导入失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  /// 自定义源分组弹窗（对标原版 alertCustomGroup）
  Future<void> _showCustomGroupDialog() async {
    final result = await showDialog<(String, bool)>(
      context: context,
      builder: (_) => CustomGroupDialog(
        initialName: _groupName ?? '',
        initialAddGroup: _isAddGroup,
      ),
    );
    if (result == null || !mounted) return;
    final (name, addGroup) = result;
    setState(() {
      _groupName = name.isEmpty ? null : name;
      _isAddGroup = addGroup;
    });
  }

  /// 查看规则 JSON（对标原版 tvOpen → CodeDialog：
  /// 展示类型化规则；解析失败时展示原始 JSON）
  Future<void> _showRuleJson(int index) => showImportJson(
    context,
    title: _displayName(index),
    json: const JsonEncoder.withIndent('  ')
        .convert(_parsed[index]?.toJson() ?? widget.raws[index]),
  );

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ImportConfirmScaffold(
      confirmText: '确认',
      title: const Text('导入替换规则'),
      actions: [
        // 自定义源分组（对标 menu_new_group，always 显示）
        TextButton(
          style: TextButton.styleFrom(foregroundColor: colorScheme.onPrimary),
          onPressed: _showCustomGroupDialog,
          child: Text(
            _groupName == null
                ? '自定义源分组'
                : '${_isAddGroup ? '+' : ''}$_groupName',
          ),
        ),
        AppMenuButton<String>(
          tooltip: '更多选项',
          // 菜单在顶栏下方展开，不覆盖顶栏
          onSelected: _handleMenu,
          itemBuilder: (_) => [
            AppMenuItem(
              value: 'keep_name',
              checked: _keepName,
              child: const Text('保留原名'),
            ),
          ],
        ),
      ],
      emptyMessage: '格式错误，未解析到替换规则',
      itemCount: widget.raws.length,
      selectedCount: _selectCount,
      allSelected: _isSelectAll,
      importing: _importing,
      itemBuilder: (_, index) => _buildItem(index),
      onToggleAll: () {
        final selectAll = _isSelectAll;
        setState(() {
          for (var i = 0; i < _selected.length; i++) {
            _selected[i] = !selectAll;
          }
        });
      },
      onCancel: () => Navigator.of(context).pop(0),
      onConfirm: _confirmImport,
    );
  }

  void _handleMenu(String value) {
    setState(() {
      switch (value) {
        case 'keep_name':
          // 对标原版：仅切换显示状态（原版持久化偏好，
          // importSelect 不应用该选项）
          _keepName = !_keepName;
      }
    });
  }

  /// 单个候选规则项（对标 item_source_import.xml：
  /// 勾选框 + 名称(分组) + 状态标签 + 打开按钮）
  Widget _buildItem(int index) {
    return ImportCandidateTile(
      title: _displayName(index),
      status: _statusOf(index),
      selected: _selected[index],
      onChanged: (value) => setState(() => _selected[index] = value),
      onOpen: () => _showRuleJson(index),
    );
  }
}
