import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localization.dart';
import '../../audio/application/audio_notifier.dart';
import '../../../widgets/bottom_sheet_widget.dart';
import '../../../widgets/settings_widgets.dart';

/// 经典面板、独立播放器与音频书共用入口，计时只由 AudioNotifier 持有。— Codex + UI
Future<void> showReadAloudTimerSheet(
  BuildContext context,
  AudioNotifier notifier,
) => AppBottomSheet.showContent<void>(
  context: context,
  showDragHandle: true,
  builder: (_) => _ReadAloudTimerSheet(notifier: notifier),
);

class _ReadAloudTimerSheet extends StatefulWidget {
  const _ReadAloudTimerSheet({required this.notifier});
  final AudioNotifier notifier;

  @override
  State<_ReadAloudTimerSheet> createState() => _ReadAloudTimerSheetState();
}

class _ReadAloudTimerSheetState extends State<_ReadAloudTimerSheet> {
  late SleepTimerMode _mode;
  late double _minutes;
  late double _chapters;
  late bool _finishChapter;
  bool _previewing = false;

  @override
  void initState() {
    super.initState();
    final timer = widget.notifier;
    _mode = timer.sleepTimerMode == SleepTimerMode.chapters
        ? SleepTimerMode.chapters
        : SleepTimerMode.duration;
    _minutes = timer.sleepRemainingSeconds > 0
        ? (timer.sleepRemainingSeconds / 60).ceilToDouble()
        : 0;
    _chapters = timer.chaptersToStopRemaining > 0
        ? timer.chaptersToStopRemaining.toDouble()
        : 0;
    _finishChapter = timer.finishCurrentChapterAfterTimer;
  }

  void _apply({bool close = false}) {
    if (_mode == SleepTimerMode.chapters) {
      widget.notifier.startChapterStop(_chapters.round());
    } else {
      widget.notifier.startSleepTimer(
        _minutes.round(),
        finishCurrentChapter: _finishChapter,
      );
    }
    setState(() => _previewing = false);
    if (close) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    final byChapter = _mode == SleepTimerMode.chapters;
    String valueLabel(int value) => value == 0
        ? strings.close
        : byChapter
        ? value == 1
              ? strings.readAloudCurrentChapter
              : strings.readAloudChapters(value)
        : strings.readAloudMinutes(value);
    return ListenableBuilder(
      listenable: widget.notifier,
      builder: (context, _) => AppBottomSheet.content(
        title: strings.readAloudTimer,
        titleSuffix: Text(
          _previewing || !widget.notifier.isSleepTimerActive
              ? valueLabel((byChapter ? _chapters : _minutes).round())
              : byChapter && widget.notifier.chaptersToStopRemaining == 1
              ? strings.readAloudCurrentChapter
              : widget.notifier.sleepTimerRemainingLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SegmentedButton<SleepTimerMode>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: SleepTimerMode.duration,
                      label: Text(strings.readAloudTimerTimeMode),
                    ),
                    ButtonSegment(
                      value: SleepTimerMode.chapters,
                      label: Text(strings.readAloudTimerChapterMode),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (values) {
                    setState(() => _mode = values.single);
                    _apply();
                  },
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Slider(
                  min: 0,
                  max: byChapter
                      ? kMaxChapterStopCount.toDouble()
                      : kMaxSleepTimerMinutes.toDouble(),
                  divisions: byChapter
                      ? kMaxChapterStopCount
                      : kMaxSleepTimerMinutes,
                  value: byChapter ? _chapters : _minutes,
                  label: valueLabel((byChapter ? _chapters : _minutes).round()),
                  onChanged: (value) => setState(() {
                    _previewing = true;
                    if (byChapter) {
                      _chapters = value;
                    } else {
                      _minutes = value;
                    }
                  }),
                  onChangeEnd: (_) => _apply(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: AppSheetPresetGrid(
                  maxColumns: 5,
                  minItemWidth: 56,
                  children: [
                    for (final value
                        in byChapter ? [1, 2, 3, 4, 5] : [10, 30, 45, 60, 90])
                      ActionChip(
                        labelPadding: EdgeInsets.zero,
                        label: Text(valueLabel(value)),
                        onPressed: () {
                          setState(() {
                            if (byChapter) {
                              _chapters = value.toDouble();
                            } else {
                              _minutes = value.toDouble();
                            }
                          });
                          _apply(close: true);
                        },
                      ),
                  ],
                ),
              ),
              if (!byChapter) ...[
                const SizedBox(height: 12),
                SettingSwitchRow(
                  title: strings.readAloudTimerFinishChapter,
                  subtitle: strings.readAloudTimerFinishChapterHint,
                  value: _finishChapter,
                  onChanged: (value) {
                    setState(() => _finishChapter = value);
                    widget.notifier.setFinishCurrentChapterAfterTimer(value);
                  },
                ),
              ],
              if (widget.notifier.isSleepTimerActive) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextButton.icon(
                    onPressed: () {
                      widget.notifier.cancelSleepTimer();
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.timer_off_outlined),
                    label: Text(strings.readAloudCancelTimer),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
