import 'package:material_ui/material_ui.dart';

import '../../../domain/models/import_result.dart';
import '../../../l10n/app_localization.dart';
import '../../../utils/error_message.dart';
import '../../../widgets/app_snack_bar.dart';

/// 确认页及两个入口共用结果展示，只有全部成功才用成功提示。— Codex + UI
Future<void> showSourceImportResult(
  BuildContext context,
  ImportResult result, {
  Future<String?> Function()? onRefresh,
}) async {
  if (!context.mounted) return;
  if (result.success > 0 &&
      result.failed == 0 &&
      result.skipped == 0 &&
      !result.hasErrors &&
      result.refreshError == null) {
    showAppSnackBar(
      context,
      context.l10n.sourceImportSuccessCount(result.success),
    );
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (_) =>
        _SourceImportResultDialog(result: result, onRefresh: onRefresh),
  );
}

class _SourceImportResultDialog extends StatefulWidget {
  const _SourceImportResultDialog({required this.result, this.onRefresh});
  final ImportResult result;
  final Future<String?> Function()? onRefresh;

  @override
  State<_SourceImportResultDialog> createState() =>
      _SourceImportResultDialogState();
}

class _SourceImportResultDialogState extends State<_SourceImportResultDialog> {
  late String? _refreshError = widget.result.refreshError;
  bool _refreshing = false;

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    String? error;
    try {
      error = await widget.onRefresh!();
    } catch (e) {
      error = errorMessage(e);
    }
    if (!mounted) return;
    setState(() {
      _refreshError = error;
      _refreshing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.sourceImportResultTitle),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.sourceImportSummary(
              result.total,
              result.success,
              result.failed,
              result.skipped,
            ),
          ),
          if (result.errors.isNotEmpty) ...[
            const SizedBox(height: 12),
            SelectableText(result.errors.join('\n\n')),
          ],
          if (_refreshError != null) ...[
            const SizedBox(height: 12),
            Text(l10n.sourceImportRefreshFailed(_refreshError!)),
          ],
        ],
      ),
      actions: [
        if (_refreshError != null && widget.onRefresh != null)
          TextButton(
            onPressed: _refreshing ? null : _refresh,
            child: Text(l10n.reload),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.close),
        ),
      ],
    );
  }
}
