import 'app_snack_bar.dart';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/app_localization.dart';
import '../theme/import_status_colors.dart';
import 'app_scaffold.dart';
import 'legado_app_bar.dart';

/// 只表达展示状态；各领域自行判定更新及默认勾选。— Codex + UI
enum ImportCandidateStatus { isNew, isUpdate, exists }

/// 导入确认公共界面，不持有候选实体、解析或写入逻辑。— Codex + UI
class ImportConfirmScaffold extends StatelessWidget {
  const ImportConfirmScaffold({
    super.key,
    required this.title,
    required this.actions,
    required this.emptyMessage,
    required this.itemCount,
    required this.selectedCount,
    required this.allSelected,
    required this.importing,
    required this.itemBuilder,
    required this.onToggleAll,
    required this.onCancel,
    required this.onConfirm,
    this.listPadding = const EdgeInsets.symmetric(vertical: 8),
    this.separatorIndent = 16,
    this.confirmText,
  });

  final Widget title;
  final List<Widget> actions;
  final String emptyMessage;
  final int itemCount;
  final int selectedCount;
  final bool allSelected;
  final bool importing;
  final IndexedWidgetBuilder itemBuilder;
  final VoidCallback onToggleAll;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final EdgeInsetsGeometry listPadding;
  final double separatorIndent;
  final String? confirmText;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return AppScaffold(
      topBar: LegadoAppBar(title: title, actions: actions),
      body: itemCount == 0
          ? Center(child: Text(emptyMessage))
          : ListView.separated(
              padding: listPadding,
              itemCount: itemCount,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, indent: separatorIndent),
              itemBuilder: itemBuilder,
            ),
      bottomBar: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(
            top: BorderSide(
              color: colors.outlineVariant.withValues(alpha: 0.6),
              width: 0.5,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextButton(
                    onPressed: onToggleAll,
                    child: Text(
                      allSelected
                          ? l10n.deselectAllCount(selectedCount, itemCount)
                          : l10n.selectAllCount(selectedCount, itemCount),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: importing ? null : onCancel,
                  child: Text(l10n.cancel),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: importing || selectedCount == 0 ? null : onConfirm,
                  child: importing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(confirmText ?? l10n.confirm),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 候选项只回传选择和预览事件，不解释原始数据。— Codex + UI
class ImportCandidateTile extends StatelessWidget {
  const ImportCandidateTile({
    super.key,
    required this.title,
    required this.status,
    required this.selected,
    required this.onChanged,
    required this.onOpen,
    this.comment,
    this.titleStyle,
    this.statusStyle,
  });

  final String title;
  final ImportCandidateStatus status;
  final bool selected;
  final ValueChanged<bool> onChanged;
  final VoidCallback onOpen;
  final String? comment;
  final TextStyle? titleStyle;
  final TextStyle? statusStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = context.l10n;
    final (label, color) = switch (status) {
      ImportCandidateStatus.isNew => (
        l10n.importStatusNew,
        AppColorsExt.importNew(colors),
      ),
      ImportCandidateStatus.isUpdate => (
        l10n.importStatusUpdated,
        AppColorsExt.importUpdate(colors),
      ),
      ImportCandidateStatus.exists => (
        l10n.importStatusExisting,
        colors.onSurfaceVariant,
      ),
    };
    final description = comment?.trim() ?? '';
    return InkWell(
      onTap: () => onChanged(!selected),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          children: [
            Checkbox(
              value: selected,
              onChanged: (value) => onChanged(value ?? false),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle ?? theme.textTheme.titleSmall,
                  ),
                  if (description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                label,
                style: (statusStyle ?? theme.textTheme.labelSmall)?.copyWith(
                  color: color,
                ),
              ),
            ),
            TextButton(onPressed: onOpen, child: Text(l10n.open)),
          ],
        ),
      ),
    );
  }
}

/// 调用方决定原始/类型化JSON，公共层仅负责展示和复制。— Codex + UI
Future<void> showImportJson(
  BuildContext context, {
  required String title,
  required String json,
}) => showDialog<void>(
  context: context,
  builder: (ctx) => AlertDialog(
    title: Text(title),
    content: SizedBox(
      width: double.maxFinite,
      child: SingleChildScrollView(
        child: SelectableText(
          json,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: json));
          if (ctx.mounted) {
            showAppSnackBar(ctx, ctx.l10n.copiedToClipboard);
          }
        },
        child: Text(ctx.l10n.copy),
      ),
      TextButton(
        onPressed: () => Navigator.pop(ctx),
        child: Text(ctx.l10n.close),
      ),
    ],
  ),
);
