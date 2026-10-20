import 'package:material_ui/material_ui.dart';

/// 设置表单的公共几何与提示，不拥有控制器、校验或持久化。— Codex + UI
class AppSettingsForm extends StatelessWidget {
  const AppSettingsForm({
    super.key,
    required this.children,
    this.title,
    this.description,
    this.errorText,
  });
  final List<Widget> children;
  final String? title, description, errorText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        if (title != null)
          Semantics(
            headingLevel: 2,
            child: Text(title!, style: theme.textTheme.titleMedium),
          ),
        if (description != null)
          Text(
            description!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ...children,
        if (errorText != null)
          Semantics(
            liveRegion: true,
            child: Text(
              errorText!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }
}
