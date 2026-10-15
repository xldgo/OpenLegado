import 'package:material_ui/material_ui.dart';

import '../l10n/app_localization.dart';
import 'bottom_sheet_widget.dart';

/// 设置编辑器固定操作栏，保存与关闭策略由页面负责。— Codex + UI
class AppSettingsSheet extends StatelessWidget {
  const AppSettingsSheet({
    super.key,
    required this.title,
    required this.child,
    required this.onSave,
    this.onClose,
    this.contentPadding = EdgeInsets.zero,
  });
  final String title;
  final Widget child;
  final VoidCallback? onSave;
  final VoidCallback? onClose;
  final EdgeInsets contentPadding;

  @override
  Widget build(BuildContext context) => AppBottomSheet.content(
    title: title,
    contentPadding: contentPadding,
    leading: TextButton(
      onPressed: onClose ?? () => Navigator.pop(context),
      child: Text(context.l10n.cancel),
    ),
    trailing: FilledButton(onPressed: onSave, child: Text(context.l10n.save)),
    child: child,
  );
}
