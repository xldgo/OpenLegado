import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../widgets/md3_heatmap_calendar.dart';

/// 阅读热力图卡片（对齐上游 HeatmapCard）
///
/// 渲染 MD3 热力图日历，支持按阅读时长和阅读本数切换查看。
class ReadingHeatmapCard extends StatefulWidget {
  final String title;
  final Map<DateTime, int> dailySeconds;
  final Map<DateTime, int> dailyCounts;
  final DateTime? endDate;
  final int weeks;
  final Md3HeatmapMode? mode;
  final ValueChanged<Md3HeatmapMode>? onModeChanged;
  final Widget? trailing;

  const ReadingHeatmapCard({
    super.key,
    this.title = '阅读热力图',
    this.dailySeconds = const {},
    this.dailyCounts = const {},
    this.endDate,
    this.weeks = 52,
    this.mode,
    this.onModeChanged,
    this.trailing,
  });

  /// 方便从 `Map<String, int>`（如 'YYYY-MM-DD'）直接构造
  factory ReadingHeatmapCard.fromStringMap({
    Key? key,
    String title = '阅读热力图',
    Map<String, int> dailySecondsMap = const {},
    Map<String, int> dailyCountsMap = const {},
    DateTime? endDate,
    int weeks = 52,
    Md3HeatmapMode? mode,
    ValueChanged<Md3HeatmapMode>? onModeChanged,
    Widget? trailing,
  }) {
    return ReadingHeatmapCard(
      key: key,
      title: title,
      dailySeconds: _parseStringDateMap(dailySecondsMap),
      dailyCounts: _parseStringDateMap(dailyCountsMap),
      endDate: endDate,
      weeks: weeks,
      mode: mode,
      onModeChanged: onModeChanged,
      trailing: trailing,
    );
  }

  static Map<DateTime, int> _parseStringDateMap(Map<String, int> map) {
    final result = <DateTime, int>{};
    for (final entry in map.entries) {
      final parts = entry.key.split('-');
      if (parts.length == 3) {
        final year = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        final day = int.tryParse(parts[2]);
        if (year != null && month != null && day != null) {
          result[DateTime(year, month, day)] = entry.value;
        }
      }
    }
    return result;
  }

  @override
  State<ReadingHeatmapCard> createState() => _ReadingHeatmapCardState();
}

class _ReadingHeatmapCardState extends State<ReadingHeatmapCard> {
  late Md3HeatmapMode _currentMode;

  @override
  void initState() {
    super.initState();
    _currentMode = widget.mode ?? Md3HeatmapMode.duration;
  }

  @override
  void didUpdateWidget(ReadingHeatmapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mode != null && widget.mode != oldWidget.mode) {
      _currentMode = widget.mode!;
    }
  }

  void _onModeChanged(Md3HeatmapMode newMode) {
    setState(() {
      _currentMode = newMode;
    });
    widget.onModeChanged?.call(newMode);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final effectiveEndDate = widget.endDate ?? DateTime.now();
    final activeMode = widget.mode ?? _currentMode;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          widget.trailing == null ? 16 : 8,
          widget.trailing == null ? 16 : 8,
          16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Symbols.grid_on_rounded, size: 20, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (widget.trailing != null) widget.trailing!,
              ],
            ),
            Padding(
              padding: EdgeInsets.only(right: widget.trailing == null ? 0 : 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Md3HeatmapCalendar(
                    dailySeconds: widget.dailySeconds,
                    dailyCounts: widget.dailyCounts,
                    mode: activeMode,
                    endDate: effectiveEndDate,
                    weeks: widget.weeks,
                    footerLeading: _ModeSwitchButton(
                      currentMode: activeMode,
                      onModeChanged: _onModeChanged,
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

class _ModeSwitchButton extends StatelessWidget {
  final Md3HeatmapMode currentMode;
  final ValueChanged<Md3HeatmapMode> onModeChanged;

  const _ModeSwitchButton({
    required this.currentMode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<Md3HeatmapMode>(
      showSelectedIcon: false,
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 8),
        ),
      ),
      segments: const [
        ButtonSegment<Md3HeatmapMode>(
          value: Md3HeatmapMode.duration,
          label: Text('时长'),
        ),
        ButtonSegment<Md3HeatmapMode>(
          value: Md3HeatmapMode.count,
          label: Text('本数'),
        ),
      ],
      selected: {currentMode},
      onSelectionChanged: (selected) {
        if (selected.isNotEmpty) {
          onModeChanged(selected.first);
        }
      },
    );
  }
}
