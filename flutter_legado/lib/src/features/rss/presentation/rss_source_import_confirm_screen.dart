import '../../../widgets/app_snack_bar.dart';
import '../../../providers/rss_repository_provider.dart';
import '../../../l10n/app_localization.dart';
import '../../../widgets/app_menu.dart';

import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import '../../../widgets/import_confirm_scaffold.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../../../models/models.dart';
import '../application/rss_notifier.dart';
import '../../../widgets/custom_group_dialog.dart';

/// 订阅源导入确认页（对标原版 ImportRssSourceDialog）
///
/// 拉取/解析出的候选订阅源在此页供用户勾选确认后才写入数据库：
/// - 列表项：勾选框 + 源名 + 新增/更新/已有 状态 + 打开（查看 JSON）
/// - 顶部菜单：自定义源分组 / 保留原名 / 保留分组 / 保留启用状态 / 显示源注释
///   （原版 RSS 导入菜单不含「选中新增源/选中更新源」）
/// - 底部：全选|取消全选（n/m）/ 取消 / 确认
class RssSourceImportConfirmScreen extends ConsumerStatefulWidget {
  /// 候选订阅源原始 JSON 列表（保留原始 Map，未入库）
  final List<Map<String, dynamic>> sources;

  /// 本地现有订阅源（用于状态判定与保留选项合并）
  final List<RssSource> localSources;

  /// 共用打开方式，保留本页参数和返回值语义。— Codex + UI
  static Future<bool?> open(
    BuildContext context, {
    required List<Map<String, dynamic>> sources,
    required List<RssSource> localSources,
  }) => Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      builder: (_) => RssSourceImportConfirmScreen(
        sources: sources,
        localSources: localSources,
      ),
    ),
  );

  const RssSourceImportConfirmScreen({
    super.key,
    required this.sources,
    required this.localSources,
  });

  @override
  ConsumerState<RssSourceImportConfirmScreen> createState() =>
      _RssSourceImportConfirmScreenState();
}

class _RssSourceImportConfirmScreenState
    extends ConsumerState<RssSourceImportConfirmScreen> {
  late final Map<String, RssSource> _localByUrl = {
    for (final s in widget.localSources) s.sourceUrl: s,
  };

  late final List<bool> _selected = [
    // 原版默认选中策略（compareImportedRssSources）：
    // 新增与更新默认选中，已有不选
    for (final s in widget.sources)
      _statusOf(s) != ImportCandidateStatus.exists,
  ];

  // 菜单选项（对标 import_source.xml：RSS 版含保留启用/源注释）
  bool _keepName = false;
  bool _keepGroup = false;
  bool _keepEnable = false;
  bool _showComment = false;

  // 自定义源分组
  String? _groupName;
  bool _isAddGroup = false;

  bool _importing = false;

  String _urlOf(Map<String, dynamic> raw) =>
      (raw['sourceUrl'] ?? '').toString();

  String _nameOf(Map<String, dynamic> raw) =>
      (raw['sourceName'] ?? '').toString();

  String? _commentOf(Map<String, dynamic> raw) =>
      raw['sourceComment']?.toString();

  int _lastUpdateTimeOf(Map<String, dynamic> raw) =>
      int.tryParse((raw['lastUpdateTime'] ?? '0').toString()) ?? 0;

  ImportCandidateStatus _statusOf(Map<String, dynamic> raw) {
    final local = _localByUrl[_urlOf(raw)];
    if (local == null) return ImportCandidateStatus.isNew;
    if (local.lastUpdateTime < _lastUpdateTimeOf(raw)) {
      return ImportCandidateStatus.isUpdate;
    }
    return ImportCandidateStatus.exists;
  }

  int get _selectCount {
    var count = 0;
    for (final b in _selected) {
      if (b) count++;
    }
    return count;
  }

  bool get _isSelectAll => _selected.every((b) => b);

  /// 确认导入：应用保留选项与自定义分组后写库
  /// （对标 ImportRssSourceViewModel.importSelect）
  ///
  /// 直传选中项的原始 JSON（仅在 raw Map 上覆盖保留/分组字段），
  /// 不经 freezed 类型化往返，由 Rust 侧宽松反序列化兜底
  /// （第三方订阅源非常规字段）。
  Future<void> _confirmImport() async {
    final l10n = context.l10n;
    if (_selectCount == 0) return;
    setState(() => _importing = true);
    try {
      final group = _groupName?.trim();
      final toImport = <Map<String, dynamic>>[];
      for (var i = 0; i < widget.sources.length; i++) {
        if (!_selected[i]) continue;
        // 拷贝原始 Map，避免污染预览条目持有的原对象
        final raw = Map<String, dynamic>.from(widget.sources[i]);
        final local = _localByUrl[_urlOf(raw)];
        if (local != null) {
          if (_keepName) {
            raw['sourceName'] = local.sourceName;
          }
          if (_keepGroup) {
            raw['sourceGroup'] = local.sourceGroup;
          }
          if (_keepEnable) {
            raw['enabled'] = local.enabled;
          }
          // 对标原版：customOrder 恒保留本地
          raw['customOrder'] = local.customOrder;
        }
        if (group != null && group.isNotEmpty) {
          if (_isAddGroup) {
            final groups = <String>{
              ...?raw['sourceGroup']
                  ?.toString()
                  .split(',')
                  .map((g) => g.trim())
                  .where((g) => g.isNotEmpty),
              group,
            };
            raw['sourceGroup'] = groups.join(',');
          } else {
            raw['sourceGroup'] = group;
          }
        }
        toImport.add(raw);
      }

      await ref
          .read(rssSourceRepositoryProvider)
          .importRssSources(jsonEncode(toImport));
      await ref.read(rssNotifierProvider.notifier).loadSources();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, l10n.importFailed(e.toString()));
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  /// 自定义源分组弹窗（对标原版 alertCustomGroup：
  /// 添加分组开关 + 分组名称输入）
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

  /// 查看订阅源 JSON（对标原版 tvOpen → CodeDialog）：直接展示原始 JSON
  Future<void> _showSourceJson(Map<String, dynamic> raw) => showImportJson(
    context,
    title: _nameOf(raw),
    json: const JsonEncoder.withIndent('  ').convert(raw),
  );

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ImportConfirmScaffold(
      title: Text(context.l10n.importRssSources),
      actions: [
        // 自定义源分组（对标 menu_new_group，always 显示）
        TextButton(
          style: TextButton.styleFrom(foregroundColor: colorScheme.onPrimary),
          onPressed: _showCustomGroupDialog,
          child: Text(
            _groupName == null
                ? context.l10n.customSourceGroup
                : '${_isAddGroup ? '+' : ''}$_groupName',
          ),
        ),
        AppMenuButton<String>(
          tooltip: context.l10n.more,
          // 菜单在顶栏下方展开，不覆盖顶栏
          onSelected: _handleMenu,
          itemBuilder: (_) => [
            AppMenuItem(
              value: 'keep_name',
              checked: _keepName,
              child: Text(context.l10n.keepSourceName),
            ),
            AppMenuItem(
              value: 'keep_group',
              checked: _keepGroup,
              child: Text(context.l10n.keepSourceGroup),
            ),
            AppMenuItem(
              value: 'keep_enable',
              checked: _keepEnable,
              child: Text(context.l10n.keepSourceEnabled),
            ),
            AppMenuItem(
              value: 'show_comment',
              checked: _showComment,
              child: Text(context.l10n.showSourceComment),
            ),
          ],
        ),
      ],
      emptyMessage: context.l10n.invalidRssSources,
      itemCount: widget.sources.length,
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
      onCancel: () => Navigator.of(context).pop(false),
      onConfirm: _confirmImport,
    );
  }

  void _handleMenu(String value) {
    setState(() {
      switch (value) {
        case 'keep_name':
          _keepName = !_keepName;
        case 'keep_group':
          _keepGroup = !_keepGroup;
        case 'keep_enable':
          _keepEnable = !_keepEnable;
        case 'show_comment':
          _showComment = !_showComment;
      }
    });
  }

  /// 单个候选订阅源项（对标 item_source_import.xml：
  /// 勾选框 + 源名 + 状态标签 + 打开按钮 + 可选源注释）
  Widget _buildItem(int index) {
    final raw = widget.sources[index];
    return ImportCandidateTile(
      title: _nameOf(raw),
      status: _statusOf(raw),
      selected: _selected[index],
      onChanged: (value) => setState(() => _selected[index] = value),
      onOpen: () => _showSourceJson(raw),
      comment: _showComment ? _commentOf(raw) : null,
    );
  }
}
