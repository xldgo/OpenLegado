import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';

/// 统一搜索输入外观，筛选或提交查询由页面回调决定。
/// 2026-10-11
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    this.focusNode,
    this.autoFocus = false,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
  });

  final TextEditingController controller;
  final String hintText;
  final FocusNode? focusNode;
  final bool autoFocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => SearchBar(
        controller: controller,
        focusNode: focusNode,
        autoFocus: autoFocus,
        hintText: hintText,
        textInputAction: TextInputAction.search,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        constraints: const BoxConstraints(minHeight: 48, maxHeight: 48),
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStatePropertyAll(colors.surfaceContainerLow),
        shape: const WidgetStatePropertyAll(StadiumBorder()),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 12),
        ),
        textStyle: WidgetStatePropertyAll(
          theme.textTheme.bodyMedium?.copyWith(color: colors.onSurface),
        ),
        hintStyle: WidgetStatePropertyAll(
          theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
        ),
        leading: Icon(
          Symbols.search_rounded,
          size: 20,
          color: colors.onSurfaceVariant,
        ),
        trailing: [
          if (value.text.isNotEmpty)
            IconButton(
              tooltip: '清除搜索关键词',
              icon: const Icon(Symbols.close_rounded, size: 20),
              onPressed: () {
                controller.clear();
                if (onClear != null) {
                  onClear!();
                } else {
                  onChanged?.call('');
                }
              },
            ),
        ],
      ),
    );
  }
}

/// 标题下方的搜索行，查询按钮可与输入框同排。
class AppSearchRow extends StatelessWidget implements PreferredSizeWidget {
  const AppSearchRow({super.key, required this.field, this.action});

  final AppSearchField field;
  final Widget? action;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
    child: Row(
      children: [
        Expanded(child: field),
        if (action != null) ...[
          const SizedBox(width: 8),
          SizedBox(height: 48, child: action),
        ],
      ],
    ),
  );
}
