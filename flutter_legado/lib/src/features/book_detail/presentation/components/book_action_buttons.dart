import 'package:material_ui/material_ui.dart';

import 'package:material_symbols_icons/symbols.dart';

/// 详情独立表现组件，只消费输入和事件。— Codex + UI
class BookActionButtons extends StatelessWidget {
  const BookActionButtons({
    super.key,
    required this.inBookshelf,
    required this.onToggleShelf,
    required this.onOpenToc,
    required this.onChangeSource,
    required this.onChangeGroup,
  });
  final bool inBookshelf;
  final VoidCallback onToggleShelf;
  final VoidCallback onOpenToc;
  final VoidCallback onChangeSource;
  final VoidCallback onChangeGroup;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget card(IconData icon, String label, VoidCallback onTap) {
      // [H1] 宽由 Expanded 等分（≈76dp）；高 69dp 固定（ref 207px≈69dp）
      return SizedBox(
        height: 69,
        child: Material(
          color: cs.surfaceContainerLow,
          // [H1 | 台账 0917 反馈批七] 卡宽 76dp 圆角 15dp（ref 实测
          // 44.75px≈15dp，R/w=0.196；原 52dp 卡 10dp 圆角随卡宽放大）
          borderRadius: BorderRadius.circular(15),
          child: InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: onTap,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: cs.primary),
                const SizedBox(height: 10),
                Text(
                  label,
                  // [F1 | 台账 0917 08 批] 四按钮标签在面板区（非 hero）：
                  // onSurfaceVariant（wcag 2.79）改 onSurface 高对比；
                  // [H1] 卡宽拓宽后标签 11sp 保持可读（ref 33px≈11sp）
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(fontSize: 11, color: cs.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // [H1 | 台账 0917 反馈批七] 等分布局：左右页边距 13dp（ref 左
    // 39px≈13dp）、卡间距 10dp（ref 24-25px≈8-8.3dp，等分布局取 10
    // 使卡宽 (360-26-30)/4=76dp 对齐 ref 229px≈76dp，横向跨度 1002px
    // 对齐 ref 989px，偏差 +1.3%）
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 0),
      child: Row(
        children: [
          Expanded(
            child: card(
              inBookshelf
                  ? Symbols.playlist_remove_rounded
                  : Symbols.playlist_add_rounded,
              inBookshelf ? '已在书架' : '加书架',
              onToggleShelf,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: card(
              Symbols.format_list_bulleted_rounded,
              '查看目录',
              onOpenToc,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: card(Symbols.swap_horiz_rounded, '书源', onChangeSource),
          ),
          const SizedBox(width: 10),
          Expanded(child: card(Symbols.folder_rounded, '设置分组', onChangeGroup)),
        ],
      ),
    );
  }
}
