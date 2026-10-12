import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../l10n/app_localization.dart';

import 'legado_app_bar.dart';
import 'app_search_field.dart';

/// [UI_SYNC_REFACTOR S1b] Dynamic 搜索行顶栏（对齐参考仓 DynamicTopAppBar）
///
/// 结构：标题文字 + 右侧搜索切换钮（actions 前置）+ bottomContent 搜索行
/// 可追加常驻 bottom（如发现页 FilterChip 横滑条）。
/// 展开状态由页面控制，保证 Scaffold 同步读取实际顶栏高度。
class DynamicSearchAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final String title;

  /// 副标题（对齐参考 DynamicTopAppBar subtitle：发现/订阅显示当前分组名）
  final String? subtitle;
  final List<Widget>? actions;
  final TextEditingController searchController;
  final String searchHint;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;

  /// 常驻 bottom（如发现 FilterChips 48dp 横滑条），位于搜索行之下
  final PreferredSizeWidget? persistentBottom;

  const DynamicSearchAppBar({
    super.key,
    required this.title,
    this.subtitle,
    required this.searchController,
    required this.searchHint,
    required this.onChanged,
    this.actions,
    this.onClear,
    required this.expanded,
    required this.onExpandedChanged,
    this.persistentBottom,
  });

  @override
  Size get preferredSize {
    final bottomH =
        (persistentBottom?.preferredSize.height ?? 0) + (expanded ? 64 : 0);
    return Size.fromHeight(kToolbarHeight + bottomH);
  }

  @override
  Widget build(BuildContext context) {
    return LegadoAppBar(
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontSize: 28),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
      actions: [
        // [UI_SYNC_REFACTOR S1b] 搜索切换钮（对齐参考 onSearchToggle）
        IconButton(
          tooltip: expanded ? context.l10n.collapseSearch
              : context.l10n.expandSearch,
          icon: Icon(
            expanded ? Symbols.search_off_rounded : Symbols.search_rounded,
          ),
          onPressed: () {
            if (expanded) FocusScope.of(context).unfocus();
            onExpandedChanged(!expanded);
          },
        ),
        ...?actions,
      ],
      bottom: !expanded && persistentBottom == null
          ? null
          : PreferredSize(
              preferredSize: Size.fromHeight(
                (persistentBottom?.preferredSize.height ?? 0) +
                    (expanded ? 64 : 0),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (expanded)
                    AppSearchRow(
                      field: AppSearchField(
                        controller: searchController,
                        hintText: searchHint,
                        onChanged: onChanged,
                        onClear: onClear,
                      ),
                    ),
              ?persistentBottom,
                ],
              ),
            ),
    );
  }
}
