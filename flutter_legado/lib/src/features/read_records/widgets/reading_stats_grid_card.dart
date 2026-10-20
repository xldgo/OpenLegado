import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';

/// 阅读指标项
@immutable
class StatItem {
  final String label;
  final String value;

  const StatItem({required this.label, required this.value});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StatItem &&
          runtimeType == other.runtimeType &&
          label == other.label &&
          value == other.value;

  @override
  int get hashCode => Object.hash(label, value);
}

/// 阅读数据网格卡片（对齐上游 StatsGridCard）
///
/// 2列网格展示指标项（阅读时长、阅读天数、读过书籍、读完书籍、在读书籍等）
class ReadingStatsGridCard extends StatelessWidget {
  final String title;
  final List<StatItem> items;
  final Widget? trailing;

  const ReadingStatsGridCard({
    super.key,
    this.title = '阅读数据',
    required this.items,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Symbols.equalizer_rounded, size: 20, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 16),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    '暂无统计数据',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              Column(
                children: [
                  for (int i = 0; i < items.length; i += 2) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _StatCell(item: items[i])),
                        const SizedBox(width: 12),
                        Expanded(
                          child: (i + 1 < items.length)
                              ? _StatCell(item: items[i + 1])
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                    if (i + 2 < items.length) const SizedBox(height: 16),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final StatItem item;

  const _StatCell({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          item.label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: cs.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          item.value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: cs.primary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
