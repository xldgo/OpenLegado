import '../../widgets/app_snack_bar.dart';
import '../../widgets/app_menu.dart';
import '../../l10n/app_localization.dart';

import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import '../../widgets/import_confirm_scaffold.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../../models/models.dart';
import 'source_notifier.dart';
import '../../domain/models/source_preview.dart';
import '../../domain/models/import_result.dart';
import '../../widgets/custom_group_dialog.dart';
import 'widgets/source_import_result.dart';

/// 书源导入确认页（对标原版 ImportBookSourceDialog）
///
/// 拉取/解析出的候选书源在此页供用户勾选确认后才写入数据库：
/// - 列表项：勾选框 + 源名 + 新增/更新/已有 状态 + 打开（查看 JSON）
/// - 顶部菜单：自定义源分组 / 选中新增源 / 选中更新源 /
///   保留原名 / 保留分组 / 保留启用状态 / 显示源注释
/// - 底部：全选|取消全选（n/m）/ 取消 / 确认
class SourceImportConfirmScreen extends ConsumerStatefulWidget {
  /// 候选书源预览列表（保留原始 JSON，未入库）
  final List<SourcePreview> sources;

  /// 本地现有书源（用于新增/更新状态判定与保留选项合并）
  final List<BookSource> localSources;

  /// 返回真实导入结果；取消或直接返回不报告成功。— Codex + UI
  static Future<ImportResult?> open(
    BuildContext context, {
    required List<SourcePreview> sources,
    required List<BookSource> localSources,
  }) => Navigator.of(context).push<ImportResult>(
    MaterialPageRoute<ImportResult>(
      builder: (_) => SourceImportConfirmScreen(
        sources: sources,
        localSources: localSources,
      ),
    ),
  );

  const SourceImportConfirmScreen({
    super.key,
    required this.sources,
    required this.localSources,
  });

  @override
  ConsumerState<SourceImportConfirmScreen> createState() =>
      _SourceImportConfirmScreenState();
}

class _SourceImportConfirmScreenState
    extends ConsumerState<SourceImportConfirmScreen> {
  late final Map<String, BookSource> _localByUrl = {
    for (final s in widget.localSources) s.bookSourceUrl: s,
  };

  late final List<bool> _selected = [
    // 原版默认选中策略：新增与更新默认选中，已有不选
    for (final s in widget.sources)
      _statusOf(s) != ImportCandidateStatus.exists,
  ];

  // 菜单选项（对标 import_source.xml）
  bool _keepName = false;
  bool _keepGroup = false;
  bool _keepEnable = false;
  bool _showComment = false;

  // 自定义源分组
  String? _groupName;
  bool _isAddGroup = false;

  bool _importing = false;

  ImportCandidateStatus _statusOf(SourcePreview source) {
    final local = _localByUrl[source.bookSourceUrl];
    if (local == null) return ImportCandidateStatus.isNew;
    if (local.lastUpdateTime < source.lastUpdateTime) {
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

  bool get _isSelectAllNew {
    for (var i = 0; i < widget.sources.length; i++) {
      if (_statusOf(widget.sources[i]) == ImportCandidateStatus.isNew &&
          !_selected[i]) {
        return false;
      }
    }
    return true;
  }

  bool get _isSelectAllUpdate {
    for (var i = 0; i < widget.sources.length; i++) {
      if (_statusOf(widget.sources[i]) == ImportCandidateStatus.isUpdate &&
          !_selected[i]) {
        return false;
      }
    }
    return true;
  }

  /// 确认导入：应用保留选项与自定义分组后写库
  /// （对标 ImportBookSourceViewModel.importSelect）
  ///
  /// 直传选中项的原始 JSON（仅在 raw Map 上覆盖保留/分组字段），
  /// 不经 freezed 类型化往返，由 Rust 侧宽松反序列化兜底
  /// （字符串数字/字符串布尔等第三方书源字段）。
  Future<void> _confirmImport() async {
    if (_importing || _selectCount == 0) return;
    setState(() => _importing = true);
    try {
      final group = _groupName?.trim();
      final toImport = <Map<String, dynamic>>[];
      for (var i = 0; i < widget.sources.length; i++) {
        if (!_selected[i]) continue;
        final preview = widget.sources[i];
        // 拷贝原始 Map，避免污染预览条目持有的原对象
        final raw = Map<String, dynamic>.from(preview.raw);
        final local = _localByUrl[preview.bookSourceUrl];
        if (local != null) {
          if (_keepName) {
            raw['bookSourceName'] = local.bookSourceName;
          }
          if (_keepGroup) {
            raw['bookSourceGroup'] = local.bookSourceGroup;
          }
          if (_keepEnable) {
            raw['enabled'] = local.enabled;
            raw['enabledExplore'] = local.enabledExplore;
          }
          raw['customOrder'] = local.customOrder;
        }
        if (group != null && group.isNotEmpty) {
          if (_isAddGroup) {
            final groups = <String>{
              ...?raw['bookSourceGroup']
                  ?.toString()
                  .split(',')
                  .map((g) => g.trim())
                  .where((g) => g.isNotEmpty),
              group,
            };
            raw['bookSourceGroup'] = groups.join(',');
          } else {
            raw['bookSourceGroup'] = group;
          }
        }
        toImport.add(raw);
      }

      final json = jsonEncode(toImport);
      final notifier = ref.read(sourceNotifierProvider.notifier);
      final result = await notifier.importFromJson(json);
      if (!mounted) return;
      // 写入已结束，查看失败明细时不继续运行后台加载动画。— Codex + UI
      setState(() => _importing = false);
      if (result.success > 0) {
        Navigator.of(context).pop(result);
      } else {
        await showSourceImportResult(
          context,
          result,
          onRefresh: () async {
            if (!mounted) return null;
            await notifier.loadSources();
            if (!mounted) return null;
            return ref.read(sourceNotifierProvider).error;
          },
        );
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, context.l10n.importFailed(e.toString()));
      }
    } finally {
      if (mounted && _importing) setState(() => _importing = false);
    }
  }

  /// 自定义源分组弹窗（对标原版 alertCustomGroup：
  /// 添加分组开关 + 分组名称输入）
  Future<void> _showCustomGroupDialog() async {
    // controller 由对话框内容组件自持（随子树卸载释放，
    // 避免退场动画期间 dispose 引发框架断言）
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

  /// 查看书源 JSON（对标原版 tvOpen → CodeDialog）：直接展示原始 JSON
  Future<void> _showSourceJson(SourcePreview source) => showImportJson(
    context,
    title: source.bookSourceName,
    json: const JsonEncoder.withIndent('  ').convert(source.raw),
  );

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_importing,
      child: ImportConfirmScaffold(
        confirmText: context.l10n.confirmImportAction,
        title: Text(context.l10n.importSources),
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
            tooltip: context.l10n.moreOptions,
            // 菜单在顶栏下方展开，不覆盖顶栏
            onSelected: _handleMenu,
            itemBuilder: (_) => [
              AppMenuItem(
                value: 'select_new',
                child: Text(context.l10n.selectNewSources),
              ),
              AppMenuItem(
                value: 'select_update',
                child: Text(context.l10n.selectUpdatedSources),
              ),
              const AppMenuDivider(),
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
        emptyMessage: context.l10n.invalidBookSources,
        itemCount: widget.sources.length,
        selectedCount: _selectCount,
        allSelected: _isSelectAll,
        importing: _importing,
        itemBuilder: (_, index) => _buildItem(index),
        listPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        separatorIndent: 8,
        onToggleAll: () {
          final selectAll = _isSelectAll;
          setState(() {
            for (var i = 0; i < _selected.length; i++) {
              _selected[i] = !selectAll;
            }
          });
        },
        onCancel: () => Navigator.of(context).pop(),
        onConfirm: _confirmImport,
      ),
    );
  }

  void _handleMenu(String value) {
    setState(() {
      switch (value) {
        case 'select_new':
          final selectAllNew = _isSelectAllNew;
          for (var i = 0; i < widget.sources.length; i++) {
            if (_statusOf(widget.sources[i]) == ImportCandidateStatus.isNew) {
              _selected[i] = !selectAllNew;
            }
          }
        case 'select_update':
          final selectAllUpdate = _isSelectAllUpdate;
          for (var i = 0; i < widget.sources.length; i++) {
            if (_statusOf(widget.sources[i]) ==
                ImportCandidateStatus.isUpdate) {
              _selected[i] = !selectAllUpdate;
            }
          }
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

  /// 单个候选书源项（对标 item_source_import.xml：
  /// 勾选框 + 源名 + 状态标签 + 打开按钮）
  Widget _buildItem(int index) {
    final source = widget.sources[index];
    return ImportCandidateTile(
      title: source.bookSourceName,
      status: _statusOf(source),
      selected: _selected[index],
      onChanged: (value) => setState(() => _selected[index] = value),
      onOpen: () => _showSourceJson(source),
      comment: _showComment ? source.bookSourceComment : null,
      titleStyle: const TextStyle(fontSize: 16),
      statusStyle: const TextStyle(fontSize: 13),
    );
  }
}
