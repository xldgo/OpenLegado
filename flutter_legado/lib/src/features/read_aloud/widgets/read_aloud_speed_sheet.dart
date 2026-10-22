import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localization.dart';
import '../../audio/application/audio_notifier.dart';
import '../../audio/application/read_aloud_preferences.dart';
import '../../../widgets/bottom_sheet_widget.dart';
import '../../../widgets/settings_widgets.dart';

Future<void> showReadAloudSpeedSheet(BuildContext context) =>
    AppBottomSheet.showContent<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => const _ReadAloudSpeedSheet(),
    );

/// 展示共享偏好，滑动只预览，保存与实际播放参数仍交给原协调层。— Codex + UI
class _ReadAloudSpeedSheet extends ConsumerStatefulWidget {
  const _ReadAloudSpeedSheet();

  @override
  ConsumerState<_ReadAloudSpeedSheet> createState() =>
      _ReadAloudSpeedSheetState();
}

class _ReadAloudSpeedSheetState extends ConsumerState<_ReadAloudSpeedSheet> {
  bool _loading = true, _saving = false;
  String? _error;
  double? _preview;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      await ref.read(readAloudPreferencesProvider.notifier).load();
      if (mounted) {
        setState(() {
          _loading = false;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '$error';
        });
      }
    }
  }

  Future<void> _save(Future<void> Function() action) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _preview = null;
        });
      }
    }
  }

  void _speed(double speed) {
    unawaited(
      _save(
        () => ref
            .read(audioNotifierProvider.notifier)
            .setReadAloudSpeed(speed, activateManual: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    final prefs = ref.watch(readAloudPreferencesProvider);
    final audio = ref.watch(audioNotifierProvider);
    final enabled =
        !_loading && !_saving && prefs.loaded && !audio.isStreamMode;
    final speed = (_preview ?? prefs.effectiveSpeed).clamp(0.5, 3.0);
    return AppBottomSheet.content(
      title: strings.readAloudSpeed,
      child: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_loading || _saving) const LinearProgressIndicator(),
            if (_error != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  prefs.loaded
                      ? strings.readAloudSaveFailed(_error!)
                      : '${strings.loadFailed}：$_error',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
              if (!prefs.loaded)
                TextButton(onPressed: _load, child: Text(strings.retry)),
            ],
            SettingSwitchRow(
              title: strings.readAloudFollowSystem,
              value: prefs.followSystem,
              onChanged: enabled
                  ? (value) => unawaited(
                      _save(
                        () => ref
                            .read(audioNotifierProvider.notifier)
                            .setReadAloudFollowSystem(value),
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 12),
            Text(
              '${speed.toStringAsFixed(1)}×',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Slider(
                min: 0.5,
                max: 3,
                divisions: 25,
                value: speed,
                label: '${speed.toStringAsFixed(1)}×',
                onChanged: enabled
                    ? (value) => setState(() => _preview = value)
                    : null,
                onChangeEnd: enabled ? _speed : null,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AppSheetPresetGrid(
                children: [
                  for (final rate in [0.5, 0.8, 1.0, 1.2, 1.5, 2.0, 2.5, 3.0])
                    ChoiceChip(
                      showCheckmark: false,
                      label: Text('${rate.toStringAsFixed(1)}×'),
                      selected:
                          !prefs.followSystem &&
                          (prefs.manualSpeed - rate).abs() < 0.001,
                      onSelected: enabled ? (_) => _speed(rate) : null,
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
