import '../../../domain/errors/app_exception.dart';

import 'dart:io';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../providers/highlight_repository_provider.dart';
import '../../../providers/network_provider.dart';
import '../../../widgets/app_menu.dart';
import '../../../widgets/app_settings_sheet.dart';
import '../../../widgets/bottom_sheet_widget.dart';
import 'highlight_rule_selection_sheet.dart';
import '../../../domain/models/highlight_rule.dart';

import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../widgets/app_scaffold.dart';
import '../../../widgets/legado_app_bar.dart';
import 'highlight_rule_edit_sheet.dart';
import '../../../widgets/settings_widgets.dart';
import '../../../widgets/md3_fast_scroller.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../application/highlight_rules/highlight_rules_notifier.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading_indicator.dart';

/// 高亮规则管理页面
///
/// 对标 Android 原版 [HighlightRuleActivity]（ui/highlight/HighlightRuleActivity.kt）：
/// - 规则列表（按 sortOrder 升序，项内显示名称/模式 + 启用开关）
/// - FAB新增，菜单提供预设与导入导出
/// - 编辑（HighlightRuleEditDialog）/ 删除（确认对话框 sure_del）
///
/// 数据经 HighlightRuleRepository 访问现有Rust highlight_api。
/// [审计修复 §4.3 第二批] JSON 解析已下沉至 HighlightRulesNotifier，
/// 本层仅消费类型化的 [HighlightRule] — Qoder
class HighlightRulesScreen extends ConsumerStatefulWidget {
  const HighlightRulesScreen({super.key});

  @override
  ConsumerState<HighlightRulesScreen> createState() =>
      _HighlightRulesScreenState();
}

class _HighlightRulesScreenState extends ConsumerState<HighlightRulesScreen> {
  // [UI_SYNC_REFACTOR R3] 快速滚动条控制器
  final ScrollController _fsController = ScrollController();
  @override
  void initState() {
    super.initState();
    // 首帧后加载，避免在 build 期间触发 notifier 状态写入
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(highlightRulesNotifierProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _fsController.dispose();
    super.dispose();
  }

  /// 删除确认（对标原版 alert(sure_del + displayName)）
  Future<void> _confirmDelete(HighlightRule rule) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('高亮规则'),
        content: Text('确定删除吗？\n${rule.displayName}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              '删除',
              style: TextStyle(color: Theme.of(ctx).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(highlightRulesNotifierProvider.notifier).deleteRule(rule);
    _showErrorIfAny();
  }

  Future<void> _edit(HighlightRule? rule) async {
    await showHighlightRuleEditor(
      context,
      rule: rule,
      onSave: (rule) async {
        final success = await ref
            .read(highlightRulesNotifierProvider.notifier)
            .saveRule(rule);
        if (!success) {
          throw AppException(
            ref.read(highlightRulesNotifierProvider).error ?? '保存失败',
          );
        }
        return true;
      },
    );
  }

  Future<void> _menu(String action) async {
    final repo = ref.read(highlightRuleRepositoryProvider);
    try {
      if (action == 'export') {
        final content = await repo.exportRules();
        if (!mounted) return;
        final box = context.findRenderObject() as RenderBox?;
        await SharePlus.instance.share(
          ShareParams(
            files: [
              XFile.fromData(
                Uint8List.fromList(utf8.encode(content)),
                mimeType: 'application/json',
              ),
            ],
            fileNameOverrides: ['highlightRules.json'],
            subject: '高亮规则',
            sharePositionOrigin: box == null
                ? null
                : box.localToGlobal(Offset.zero) & box.size,
          ),
        );
        return;
      }
      List<HighlightRule> candidates;
      if (action == 'presets') {
        candidates = await repo.presets();
      } else {
        final content = await _importContent();
        if (content == null) return;
        candidates = await repo.preview(content);
      }
      if (!mounted) return;
      if (candidates.isEmpty) {
        _notice('没有可导入的高亮规则');
        return;
      }
      final existing = (await repo.highlightRuleList())
          .map((r) => r.uuid)
          .toSet();
      if (!mounted) return;
      final selected = await selectHighlightRules(
        context,
        title: action == 'presets' ? '预设规则' : '导入高亮规则',
        rules: candidates,
        existing: existing,
      );
      if (selected == null || selected.isEmpty) return;
      final count = await repo.importRules(selected);
      ref.read(highlightRuleRevisionProvider.notifier).changed();
      await ref.read(highlightRulesNotifierProvider.notifier).load();
      _notice('已导入$count条规则');
    } catch (e) {
      _notice('操作失败：$e');
    }
  }

  void _notice(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<String?> _importContent() async {
    final controller = TextEditingController();
    final network = ref.read(networkServiceProvider);
    try {
      return await AppBottomSheet.showContent<String>(
        context: context,
        builder: (ctx) => AppSettingsSheet(
          title: '导入高亮规则',
          onSave: () => Navigator.pop(ctx, controller.text),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Symbols.folder_open_rounded),
                title: const Text('选择文件'),
                onTap: () async {
                  try {
                    final picked = await FilePicker.pickFile();
                    if (picked?.path == null) return;
                    final content = await File(picked!.path!).readAsString();
                    if (ctx.mounted) Navigator.pop(ctx, content);
                  } catch (e) {
                    _notice('读取失败：$e');
                  }
                },
              ),
              ListTile(
                leading: const Icon(Symbols.content_paste_rounded),
                title: const Text('粘贴剪贴板'),
                onTap: () async {
                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                  if (ctx.mounted && data?.text != null) {
                    controller.text = data!.text!;
                  }
                },
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: controller,
                  minLines: 3,
                  maxLines: 8,
                  decoration: const InputDecoration(labelText: '规则JSON或链接'),
                ),
              ),
            ],
          ),
        ),
      ).then((content) async {
        if (content == null || content.trim().isEmpty) return null;
        final uri = Uri.tryParse(content.trim());
        if (uri?.scheme == 'https' || uri?.scheme == 'http') {
          return (await network.httpGet(content.trim())).body;
        }
        return content;
      });
    } finally {
      controller.dispose();
    }
  }

  /// notifier 状态中的错误提示到 UI（避免静默吞噬）
  void _showErrorIfAny() {
    final error = ref.read(highlightRulesNotifierProvider).error;
    if (error == null || !mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('操作失败: $error')));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final state = ref.watch(highlightRulesNotifierProvider);
    // [GLOBALCOMP B4] 页壳统一：AppScaffold（行为等价直通 Scaffold）
    return AppScaffold(
      topBar: LegadoAppBar(
        title: const Text('高亮规则'),
        actions: [
          AppMenuButton<String>(
            onSelected: _menu,
            itemBuilder: (_) => const [
              AppMenuItem(value: 'presets', child: Text('预设规则')),
              AppMenuItem(value: 'import', child: Text('导入')),
              AppMenuItem(value: 'export', child: Text('导出')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(null),
        icon: const Icon(Symbols.add_rounded),
        label: const Text('新增规则'),
      ),
      body: Builder(
        builder: (context) {
          if (state.isLoading) {
            return const LoadingIndicator(message: '加载高亮规则...');
          }
          if (state.error != null && state.rules.isEmpty) {
            return Center(child: Text('操作失败: ${state.error}'));
          }
          if (state.rules.isEmpty) {
            return const EmptyState(
              icon: Symbols.format_paint_rounded,
              title: '暂无高亮规则',
              subtitle: '点击右下角按钮添加，或从右上角菜单导入',
            );
          }
          // 规则分组沿用设置卡片与分隔线样式。
          // [UI_SYNC_REFACTOR R3] 规则列表快速滚动条
          return AppScrollBody(
            controller: _fsController,
            builder: (context, scrollController) => Md3FastScroller(
              controller: scrollController,
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                children: [
                  SettingsGroup(
                    children: [
                      for (final rule in state.rules)
                        _buildRuleTile(context, rule, cs),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRuleTile(
    BuildContext context,
    HighlightRule rule,
    ColorScheme cs,
  ) {
    final scope = rule.scope ?? '';
    return InkWell(
      onTap: () => _edit(rule),
      onLongPress: () => _confirmDelete(rule),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rule.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: rule.isEnabled
                          ? cs.onSurface
                          : cs.onSurfaceVariant,
                    ),
                  ),
                  if (rule.name.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        rule.pattern,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        // 正则徽标
                        if (rule.isRegex)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '正则',
                              style: TextStyle(
                                fontSize: 10,
                                color: cs.onPrimaryContainer,
                              ),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            scope.isNotEmpty ? '范围：$scope' : '全局生效',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // 启用开关（对标原版列表项 Switch）
            // [LAYOUT_PLAN P1] 开关行无 Chevron（等价 showChevron=false）；
            // 标题/副标题/元信息走 M3 Type Scale（titleMedium/bodySmall/labelSmall）
            Switch(
              value: rule.isEnabled,
              onChanged: (v) async {
                await ref
                    .read(highlightRulesNotifierProvider.notifier)
                    .toggleEnabled(rule, v);
                _showErrorIfAny();
              },
            ),
            IconButton(
              icon: Icon(
                Symbols.delete_rounded,
                size: 20,
                color: cs.onSurfaceVariant,
              ),
              tooltip: '删除',
              visualDensity: VisualDensity.compact,
              onPressed: () => _confirmDelete(rule),
            ),
          ],
        ),
      ),
    );
  }
}
