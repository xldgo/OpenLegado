import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localization.dart';
import '../../providers/audio/audio_notifier.dart';

/// 两种朗读界面共用定时入口，计时仍由播放会话持有。
Future<void> showReadAloudTimerSheet(
  BuildContext context,
  AudioNotifier notifier,
) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => _ReadAloudTimerSheet(notifier: notifier),
);

class _ReadAloudTimerSheet extends StatefulWidget {
  const _ReadAloudTimerSheet({required this.notifier});
  final AudioNotifier notifier;

  @override
  State<_ReadAloudTimerSheet> createState() => _ReadAloudTimerSheetState();
}

class _ReadAloudTimerSheetState extends State<_ReadAloudTimerSheet> {
  final _minutes = TextEditingController();
  bool _invalid = false;

  @override
  void dispose() {
    _minutes.dispose();
    super.dispose();
  }

  void _start(int minutes) {
    if (minutes < 1 || minutes > kMaxSleepTimerMinutes) {
      setState(() => _invalid = true);
      return;
    }
    widget.notifier.startSleepTimer(minutes);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: ListenableBuilder(
            listenable: widget.notifier,
            builder: (context, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  strings.readAloudTimer,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (widget.notifier.isSleepTimerActive)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(widget.notifier.sleepTimerRemainingLabel),
                  ),
                for (final minutes in [10, 20, 30, 60])
                  ListTile(
                    leading: const Icon(Icons.timer_outlined),
                    title: Text(strings.readAloudMinutes(minutes)),
                    onTap: () => _start(minutes),
                  ),
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: TextField(
                    controller: _minutes,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: strings.readAloudCustomMinutes,
                      errorText: _invalid
                          ? strings.readAloudTimerRange(kMaxSleepTimerMinutes)
                          : null,
                    ),
                    onSubmitted: (value) => _start(int.tryParse(value) ?? 0),
                  ),
                  trailing: IconButton(
                    tooltip: strings.confirm,
                    icon: const Icon(Icons.check),
                    onPressed: () => _start(int.tryParse(_minutes.text) ?? 0),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: Text(strings.readAloudStopAfterChapter),
                  onTap: () {
                    widget.notifier.startChapterStop(1);
                    Navigator.pop(context);
                  },
                ),
                if (widget.notifier.isSleepTimerActive)
                  ListTile(
                    leading: const Icon(Icons.timer_off_outlined),
                    title: Text(strings.readAloudCancelTimer),
                    onTap: () {
                      widget.notifier.cancelSleepTimer();
                      Navigator.pop(context);
                    },
                  ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
