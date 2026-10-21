import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../l10n/app_localization.dart';
import 'legado_app_bar.dart';
import 'app_search_field.dart';
import 'app_search_transition.dart';

/// 与AppScaffold共享搜索进度，动态preferredSize不再直接跳到目标高度。
class DynamicSearchAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const DynamicSearchAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.titleWidget,
    this.leading,
    this.showBack,
    this.actions,
    required this.searchController,
    required this.searchHint,
    required this.onChanged,
    this.onSubmitted,
    this.onClear,
    required this.expanded,
    required this.onExpandedChanged,
    this.persistentBottom,
    this.progress,
    this.showSearchAction = true,
  });
  final String title;
  final String? subtitle;
  final Widget? titleWidget, leading;
  final bool? showBack;
  final List<Widget>? actions;
  final TextEditingController searchController;
  final String searchHint;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final bool expanded, showSearchAction;
  final ValueChanged<bool> onExpandedChanged;
  final PreferredSizeWidget? persistentBottom;
  final double? progress;
  double get _progress => progress ?? (expanded ? 1 : 0);
  DynamicSearchAppBar atProgress(double value) => DynamicSearchAppBar(
    key: key,
    title: title,
    subtitle: subtitle,
    titleWidget: titleWidget,
    leading: leading,
    showBack: showBack,
    actions: actions,
    searchController: searchController,
    searchHint: searchHint,
    onChanged: onChanged,
    onSubmitted: onSubmitted,
    onClear: onClear,
    expanded: expanded,
    onExpandedChanged: onExpandedChanged,
    persistentBottom: persistentBottom,
    progress: value,
    showSearchAction: showSearchAction,
  );
  @override
  Size get preferredSize => Size.fromHeight(
    kToolbarHeight +
        (persistentBottom?.preferredSize.height ?? 0) +
        64 * _progress,
  );
  @override
  Widget build(BuildContext context) => _toolbar(context);

  Widget buildSliver(
    BuildContext context, {
    required bool large,
    bool scrolledUnder = false,
  }) =>
      _toolbar(context)
          .buildSliver(context, large: large, scrolledUnder: scrolledUnder);

  LegadoAppBar _toolbar(BuildContext context) => LegadoAppBar(
    leading: leading,
    showBack: showBack,
    title:
        titleWidget ??
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
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
        ),
    actions: [
      if (showSearchAction)
        IconButton(
          tooltip: expanded
              ? context.l10n.collapseSearch
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
    bottom: _progress == 0 && persistentBottom == null
        ? null
        : PreferredSize(
            preferredSize: Size.fromHeight(
              (persistentBottom?.preferredSize.height ?? 0) + 64 * _progress,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppSearchReveal(
                  progress: _progress,
                  expanded: expanded,
                  child: SizedBox(
                    height: 64,
                    child: AppSearchRow(
                      field: AppSearchField(
                        controller: searchController,
                        hintText: searchHint,
                        onChanged: onChanged,
                        onSubmitted: onSubmitted,
                        onClear: onClear,
                      ),
                    ),
                  ),
                ),
                ?persistentBottom,
              ],
            ),
          ),
  );
}
