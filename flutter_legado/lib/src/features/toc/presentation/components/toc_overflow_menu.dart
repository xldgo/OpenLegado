import 'package:material_ui/material_ui.dart';

import '../../../../l10n/app_localization.dart';
import '../../../../models/book.dart';
import '../../../../widgets/app_menu.dart';

/// 菜单显隐由当前Tab和设置决定，动作仍由页面编排。— Codex + UI
class TocOverflowMenu extends StatelessWidget {
  const TocOverflowMenu({
    super.key,
    required this.tab,
    required this.isLocalTxt,
    required this.readConfig,
    required this.loadWordCount,
    required this.onSelected,
  });
  final int tab;
  final bool isLocalTxt, loadWordCount;
  final ReadConfig? readConfig;
  final ValueChanged<String> onSelected;
  @override
  Widget build(BuildContext context) => AppMenuButton<String>(
    tooltip: context.l10n.more,
    onSelected: onSelected,
    itemBuilder: (_) => _items(context),
  );

  List<AppMenuEntry<String>> _items(BuildContext context) {
    final items = <AppMenuEntry<String>>[];
    if (tab == 0) {
      // menu_group_text：仅本地 TXT 书可见（对齐原版 isLocalTxt 判定）
      if (isLocalTxt) {
        items.add(
          AppMenuItem(value: 'tocRegex', child: Text(context.l10n.txtTocRules)),
        );
        items.add(
          AppMenuItem(
            value: 'splitLongChapter',
            checked: readConfig?.splitLongChapter ?? true,
            child: Text(context.l10n.readerSplitLongChapters),
          ),
        );
      }
      // menu_group_toc：目录 Tab 可见
      items.add(
        AppMenuItem(
          value: 'reverseToc',
          child: Text(context.l10n.readerReverseChapterOrder),
        ),
      );
      items.add(
        AppMenuItem(
          value: 'useReplace',
          // useReplaceRule 存于 ReadConfig（对齐原版 Book.ReadConfig.useReplaceRule）
          checked: readConfig?.useReplaceRule ?? true,
          child: Text(context.l10n.readerUseReplaceRule),
        ),
      );
      items.add(
        AppMenuItem(
          value: 'loadWordCount',
          checked: loadWordCount,
          child: Text(context.l10n.readerLoadWordCount),
        ),
      );
    } else if (tab == 1) {
      // menu_group_bookmark：书签 Tab 可见
      items.add(
        AppMenuItem(
          value: 'exportBookmark',
          child: Text(context.l10n.readerExport),
        ),
      );
      items.add(
        const AppMenuItem(value: 'exportMd', child: Text('导出 Markdown')),
      );
    }
    // menu_log：始终可见
    items.add(AppMenuItem(value: 'log', child: Text(context.l10n.logs)));
    return items;
  }
}
