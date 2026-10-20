import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../read_record_overview_state.dart';
import '../read_record_screen.dart' show formatDuring;

/// 阅读时长分布柱状图数据项
typedef DailyTimeBarItem = ({DateTime date, int seconds});

/// 阅读时长分布柱状图卡片（对齐上游 ReadingTimeBarChartCard）
class ReadingTimeBarChartCard extends StatelessWidget {
  final String title;
  final List<DailyTimeBarItem> data;
  final ReadPeriod period;
  final Widget? trailing;

  const ReadingTimeBarChartCard({
    super.key,
    this.title = '阅读时长分布',
    required this.data,
    required this.period,
    this.trailing,
  });

  /// 向上取整计算最大时长对齐单位（秒）
  static int calculateRoundedMaxSeconds(int rawMaxSec) {
    if (rawMaxSec <= 0) return 60;
    if (rawMaxSec < 60) return 60;
    if (rawMaxSec < 10 * 60) {
      return ((rawMaxSec + 59) ~/ 60) * 60;
    }
    if (rawMaxSec < 60 * 60) {
      return ((rawMaxSec + 5 * 60 - 1) ~/ (5 * 60)) * (5 * 60);
    }
    if (rawMaxSec < 12 * 3600) {
      return ((rawMaxSec + 3600 - 1) ~/ 3600) * 3600;
    }
    return ((rawMaxSec + 4 * 3600 - 1) ~/ (4 * 3600)) * (4 * 3600);
  }

  /// 紧凑格式化时长（供 Y 轴使用）
  static String formatDurationCompact(int sec) {
    if (sec <= 0) return '0';
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    if (h > 0 && m > 0) return '$h时$m分';
    if (h > 0) return '$h小时';
    if (m > 0) return '$m分钟';
    return '$sec秒';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    int maxSec = 0;
    for (final item in data) {
      if (item.seconds > maxSec) {
        maxSec = item.seconds;
      }
    }
    final roundedMaxSec = calculateRoundedMaxSeconds(maxSec);

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
                Icon(Symbols.bar_chart_rounded, size: 20, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 16),
            if (data.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    '暂无时长分布数据',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              SizedBox(
                height: 140,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Y-Axis
                    SizedBox(
                      width: 38,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              formatDurationCompact(roundedMaxSec),
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 9,
                                color: cs.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.visible,
                            ),
                            Text(
                              '0',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 9,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Bars Area
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (int i = 0; i < data.length; i++)
                            Expanded(
                              child: _BarColumn(
                                item: data[i],
                                index: i,
                                totalCount: data.length,
                                period: period,
                                roundedMaxSec: roundedMaxSec,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BarColumn extends StatelessWidget {
  final DailyTimeBarItem item;
  final int index;
  final int totalCount;
  final ReadPeriod period;
  final int roundedMaxSec;

  const _BarColumn({
    required this.item,
    required this.index,
    required this.totalCount,
    required this.period,
    required this.roundedMaxSec,
  });

  String _getLabelText() {
    switch (period) {
      case ReadPeriod.week:
        switch (item.date.weekday) {
          case 1:
            return '一';
          case 2:
            return '二';
          case 3:
            return '三';
          case 4:
            return '四';
          case 5:
            return '五';
          case 6:
            return '六';
          case 7:
            return '日';
          default:
            return '';
        }
      case ReadPeriod.year:
        return '${item.date.month}月';
      case ReadPeriod.month:
        // 月视图中只在 1号、15号 和最后一天显示日期数字，避免过于拥挤
        final isKeyDay =
            item.date.day == 1 ||
            item.date.day == 15 ||
            index == totalCount - 1;
        return isKeyDay ? '${item.date.day}' : '';
      case ReadPeriod.day:
        return item.date.hour % 6 == 0 || item.date.hour == 23
            ? '${item.date.hour}'
            : '';
      case ReadPeriod.all:
        return '${item.date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final factor = (item.seconds / roundedMaxSec).clamp(0.0, 1.0);
    final labelText = _getLabelText();

    final interval = period == ReadPeriod.day
        ? ' ${item.date.hour.toString().padLeft(2, '0')}:00–${(item.date.hour + 1).toString().padLeft(2, '0')}:00'
        : '';
    final tooltip =
        '${item.date.month}月${item.date.day}日$interval · ${formatDuring(item.seconds * 1000)}';

    return Column(
      children: [
        // 柱子区域
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxHeight = constraints.maxHeight;
              final maxBarWidth = math.min(16.0, constraints.maxWidth * 0.7);

              return Align(
                alignment: Alignment.bottomCenter,
                child: Tooltip(
                  message: tooltip,
                  triggerMode: TooltipTriggerMode.tap,
                  child: Container(
                    width: math.max(2.0, maxBarWidth),
                    height: item.seconds > 0
                        ? math.max(4.0, maxHeight * factor)
                        : 2.0,
                    decoration: BoxDecoration(
                      color: item.seconds > 0
                          ? cs.primary
                          : cs.surfaceContainerHighest,
                      borderRadius: item.seconds > 0
                          ? const BorderRadius.vertical(top: Radius.circular(4))
                          : BorderRadius.circular(1),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // 底部标签
        SizedBox(
          height: 20,
          child: Center(
            child: Text(
              labelText,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 9,
                color: cs.onSurfaceVariant,
              ),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
            ),
          ),
        ),
      ],
    );
  }
}
