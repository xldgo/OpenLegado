import '../../privacy/privacy_gate.dart';

import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../widgets/book_cover.dart';

/// 读书日历中的书籍概要信息
typedef CalendarBookInfo = ({String bookName, String author, String? coverUrl});

/// 读书日历卡片（对齐上游 ReadingCalendarCard）
class ReadingCalendarCard extends StatelessWidget {
  final String title;
  final DateTime referenceDate;
  final Map<String, CalendarBookInfo> dailyTopBook;
  final ValueChanged<DateTime>? onDateTap;
  final Widget? trailing;

  const ReadingCalendarCard({
    super.key,
    this.title = '读书日历',
    required this.referenceDate,
    this.dailyTopBook = const {},
    this.onDateTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final currentYear = referenceDate.year;
    final currentMonth = referenceDate.month;
    final daysInMonth = DateTime(currentYear, currentMonth + 1, 0).day;
    final firstDayOfMonth = DateTime(currentYear, currentMonth, 1);
    // 0 for Sunday (7 % 7 == 0), 1 for Monday, ..., 6 for Saturday
    final firstDayOfWeek = firstDayOfMonth.weekday % 7;
    final totalCells = ((daysInMonth + firstDayOfWeek + 6) ~/ 7) * 7;

    const weekDays = ['日', '一', '二', '三', '四', '五', '六'];

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
                Icon(
                  Symbols.calendar_month_rounded,
                  size: 20,
                  color: cs.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: weekDays.map((day) {
                return Expanded(
                  child: Text(
                    day,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            for (int i = 0; i < totalCells; i += 7) ...[
              Row(
                children: [
                  for (int j = 0; j < 7; j++) ...[
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: AspectRatio(
                          aspectRatio: 0.75,
                          child: Builder(
                            builder: (context) {
                              final cellIndex = i + j;
                              final dayOfMonth = cellIndex - firstDayOfWeek + 1;
                              if (dayOfMonth < 1 || dayOfMonth > daysInMonth) {
                                return const SizedBox.shrink();
                              }

                              final date = DateTime(
                                currentYear,
                                currentMonth,
                                dayOfMonth,
                              );
                              final dateKey =
                                  '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                              final topBook = dailyTopBook[dateKey];

                              return _CalendarDayCell(
                                date: date,
                                topBook: topBook,
                                onTap: topBook != null && onDateTap != null
                                    ? () => onDateTap!(date)
                                    : null,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (i + 7 < totalCells) const SizedBox(height: 4),
            ],
          ],
        ),
      ),
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  final DateTime date;
  final CalendarBookInfo? topBook;
  final VoidCallback? onTap;

  const _CalendarDayCell({
    required this.date,
    required this.topBook,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hasBook = topBook != null;
    final description = hasBook
        ? '${date.month}月${date.day}日 · 《${topBook!.bookName}》 ${topBook!.author}'
        : '${date.month}月${date.day}日 无阅读记录';

    // 仅有真实阅读记录的日期可查看明细，空日期不提供点击动作。
    return PrivacyMaskedContent(
      bookName: topBook?.bookName,
      author: topBook?.author,
      onTap: onTap,
      child: Semantics(
        container: true,
        label: description,
        button: onTap != null,
        onTap: onTap,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          excludeFromSemantics: true,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasBook)
                    Opacity(
                      opacity: 0.4,
                      child: BookCover(
                        coverUrl: topBook!.coverUrl,
                        borderRadius: 6,
                      ),
                    ),
                  Center(
                    child: Text(
                      '${date.day}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: hasBook
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: hasBook ? cs.primary : cs.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
