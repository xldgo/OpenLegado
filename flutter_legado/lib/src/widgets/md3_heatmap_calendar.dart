import 'dart:math' as math;

import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/app_localization.dart';

/// 热力图配色模式（对齐参考仓库 HeatmapMode）
enum Md3HeatmapMode {
  /// 每日阅读时长（秒；数据源 readRecordDailyList，Rust 契约 2026-08-29）
  duration,

  /// 当日阅读书籍数，由每日单书明细提供。
  count,
}

/// MD3 阅读热力图日历（对齐参考仓库 HeatmapCalendar：GitHub 打卡风格，
/// 列=周、行=周一~周日，格子按 5 级配色）
///
/// - [Md3HeatmapMode.duration]：按当日阅读秒数分级（readRecordDailyList）；
/// - [Md3HeatmapMode.count]：按每日单书明细的书籍数分级。
class Md3HeatmapCalendar extends StatelessWidget {
  /// 时长模式数据：日 → 当日阅读秒数
  final Map<DateTime, int> dailySeconds;

  /// 计数模式数据：日 → 当日阅读书籍数
  final Map<DateTime, int> dailyCounts;

  /// 当前配色模式
  final Md3HeatmapMode mode;

  /// 结束日期（含当日，通常为今天）；向前铺满 [weeks] 周
  final DateTime endDate;

  /// 展示周数（默认 52 周一年）
  final int weeks;

  /// 基色（5 级由 primary 透明度阶梯派生）
  final Color? color;

  /// 卡片模式切换等控件，与图例共用底部空间；窄屏自动换行。
  final Widget? footerLeading;

  const Md3HeatmapCalendar({
    super.key,
    required this.dailySeconds,
    required this.dailyCounts,
    required this.mode,
    required this.endDate,
    this.weeks = 52,
    this.color,
    this.footerLeading,
  });

  /// 按记录列表聚合每日书籍数（lastRead 落日 + 书名去重）
  static Map<DateTime, int> aggregateDailyBookCount(
    Iterable<({String bookName, int lastRead})> records,
  ) {
    final map = <String, int>{};
    for (final r in records) {
      if (r.lastRead <= 0) continue;
      final d = DateTime.fromMillisecondsSinceEpoch(r.lastRead);
      final day = DateTime(d.year, d.month, d.day);
      final key = '${day.millisecondsSinceEpoch}:${r.bookName}';
      map[key] = (map[key] ?? 0) + 1;
    }
    final daily = <DateTime, int>{};
    for (final e in map.entries) {
      final parts = e.key.split(':');
      final day = DateTime.fromMillisecondsSinceEpoch(int.parse(parts.first));
      daily[day] = (daily[day] ?? 0) + 1;
    }
    return daily;
  }

  /// 对齐上游的单色递进，先与卡片底色合成，避免透明度受底层叠加影响。
  Color _colorForLevel(int level, ColorScheme scheme, Color base) {
    if (level <= 0) {
      return Color.alphaBlend(
        scheme.onSurface.withValues(alpha: 0.08),
        scheme.surfaceContainerLow,
      );
    }
    final opacity = switch (level) {
      1 => 0.35,
      2 => 0.55,
      3 => 0.75,
      _ => 1.0,
    };
    return Color.alphaBlend(
      base.withValues(alpha: opacity),
      scheme.surfaceContainerLow,
    );
  }

  /// 时长分级阈值（秒）：0 / <10min / <30min / <60min / ≥60min
  static int levelForSeconds(int seconds) {
    if (seconds <= 0) return 0;
    if (seconds < 600) return 1;
    if (seconds < 1800) return 2;
    if (seconds < 3600) return 3;
    return 4;
  }

  /// 计数分级：0 / 1 / 2 / 3~4 / ≥5 本
  static int levelForCount(int count) {
    if (count <= 0) return 0;
    if (count == 1) return 1;
    if (count == 2) return 2;
    if (count <= 4) return 3;
    return 4;
  }

  String _formatDuration(BuildContext context, int seconds) {
    if (seconds < 60) return context.l10n.secondCount(seconds);
    final m = seconds ~/ 60;
    if (m < 60) return context.l10n.minuteCount(m);
    return context.l10n.hourMinuteCount(m ~/ 60, m % 60);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = color ?? scheme.primary;

    // 结束日对齐到所在周的最后一天（周日）；从结束周向前铺 weeks 周
    final end = DateTime(
      endDate.year,
      endDate.month,
      endDate.day + DateTime.sunday - endDate.weekday,
    );
    final cells = <(DateTime, int)>[];
    for (var w = weeks - 1; w >= 0; w--) {
      final weekEnd = DateTime(end.year, end.month, end.day - 7 * w);
      for (var d = 6; d >= 0; d--) {
        final day = DateTime(weekEnd.year, weekEnd.month, weekEnd.day - d);
        final count = dailyCounts[day] ?? 0;
        final seconds = dailySeconds[day] ?? 0;
        final level = mode == Md3HeatmapMode.duration
            ? levelForSeconds(seconds)
            : levelForCount(count);
        cells.add((day, level));
      }
    }
    // 未来日期格子隐藏（弱化为不可见底格）
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);

    String tooltipFor(DateTime day) {
      if (day.isAfter(todayDay)) return '';
      if (mode == Md3HeatmapMode.duration) {
        return '${day.year}/${day.month}/${day.day} · ${_formatDuration(context, dailySeconds[day] ?? 0)}';
      }
      return '${day.year}/${day.month}/${day.day} · ${context.l10n.bookCount(dailyCounts[day] ?? 0)}';
    }

    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final labelSize = MediaQuery.textScalerOf(context)
        .scale(labelStyle?.fontSize ?? 11);
    const cellSize = 14.0;
    final pitch = math.max(18.0, labelSize * 1.35 + 2);
    final monthHeight = labelSize * 1.4 + 8;
    final gridWidth = weeks * pitch;
    final monthLabelWidth = math.min(gridWidth, labelSize * 5);
    final markers = <(int, DateTime)>[];
    for (var c = 0; c < weeks; c++) {
      final firstDay = cells[c * 7].$1;
      if (c == 0 || firstDay.month != cells[(c - 1) * 7].$1.month) {
        markers.add((c, firstDay));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: labelSize * 3 + 6,
              child: Column(
                children: [
                  SizedBox(height: monthHeight),
                  for (var r = 0; r < 7; r++)
                    SizedBox(
                      height: pitch,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: r.isEven
                            ? Text(
                                DateFormat('E', locale).format(cells[r].$1),
                                style: labelStyle,
                                maxLines: 1,
                              )
                            : null,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: SizedBox(
                  width: gridWidth,
                  child: Column(
                    children: [
                      SizedBox(
                        height: monthHeight,
                        child: Stack(
                          children: [
                            for (final (column, day) in markers)
                              Positioned(
                                left: math.min(
                                  column * pitch,
                                  gridWidth - monthLabelWidth,
                                ),
                                width: monthLabelWidth,
                                top: 0,
                                child: Text(
                                  DateFormat('MMM', locale).format(day),
                                  style: labelStyle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var c = 0; c < weeks; c++)
                            Column(
                              children: [
                                for (var r = 0; r < 7; r++)
                                  Builder(
                                    builder: (context) {
                                      final (day, level) = cells[c * 7 + r];
                                      final future = day.isAfter(todayDay);
                                      final cell = Container(
                                        key: ValueKey(
                                          'heatmap-day-${day.year}-${day.month}-${day.day}',
                                        ),
                                        width: cellSize,
                                        height: cellSize,
                                        decoration: BoxDecoration(
                                          color: future
                                              ? Colors.transparent
                                              : _colorForLevel(
                                                  level,
                                                  scheme,
                                                  base,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            3,
                                          ),
                                          border: day == todayDay
                                              ? Border.all(
                                                  color:
                                                      scheme.onSurfaceVariant,
                                                  width: 1.25,
                                                )
                                              : null,
                                        ),
                                      );
                                      return SizedBox(
                                        width: pitch,
                                        height: pitch,
                                        child: Center(
                                          child: future
                                              ? cell
                                              : Tooltip(
                                                  message: tooltipFor(day),
                                                  triggerMode:
                                                      TooltipTriggerMode.tap,
                                                  child: cell,
                                                ),
                                        ),
                                      );
                                    },
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // 模式切换和图例分居两侧；宽度不足时自然换行。
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            ?footerLeading,
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(context.l10n.heatmapLess, style: labelStyle),
                const SizedBox(width: 6),
                for (var level = 0; level <= 4; level++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _colorForLevel(level, scheme, base),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                const SizedBox(width: 6),
                Text(context.l10n.heatmapMore, style: labelStyle),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
