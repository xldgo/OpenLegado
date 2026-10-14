import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localization.dart';
import '../providers/ui_settings/eye_protection_notifier.dart';
import '../theme/eye_protection.dart';
import 'settings_widgets.dart';

/// 外观、完整阅读设置和阅读快捷面板共用的护眼控件。
class EyeProtectionSettingsGroup extends ConsumerWidget {
  const EyeProtectionSettingsGroup({super.key, this.flat = false});

  final bool flat;

  static void show(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.l10n.eyeProtection,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: MaterialLocalizations.of(context)
                          .closeButtonTooltip,
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(bottom: 16),
                  child: EyeProtectionSettingsGroup(flat: true),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(eyeProtectionProvider);
    final notifier = ref.read(eyeProtectionProvider.notifier);
    final strings = context.l10n;
    return SettingsGroup(
      title: flat ? null : strings.eyeProtection,
      flat: flat,
      showDividers: false,
      children: [
        SettingSwitchRow(
          title: strings.eyeProtectionEnabled,
          subtitle: strings.eyeProtectionEnabledSummary,
          value: settings.enabled,
          onChanged: (value) =>
              _save(context, () => notifier.update(enabled: value)),
        ),
        SettingSwitchRow(
          title: strings.eyeProtectionAutoNight,
          value: settings.autoNight,
          onChanged: (value) =>
              _save(context, () => notifier.update(autoNight: value)),
        ),
        if (settings.configured) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        strings.eyeProtectionIntensity,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                    Text(
                      '${settings.intensity}%',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: settings.intensity.toDouble(),
                  min: 0,
                  max: 100,
                  divisions: 100,
                  label: '${settings.intensity}%',
                  onChanged: (value) => _save(
                    context,
                    () => notifier.update(intensity: value.round()),
                  ),
                ),
              ],
            ),
          ),
          SettingSwitchRow(
            title: strings.eyeProtectionSchedule,
            subtitle: strings.eyeProtectionScheduleSummary,
            value: settings.schedule,
            onChanged: (value) =>
                _save(context, () => notifier.update(schedule: value)),
          ),
          if (settings.schedule) ...[
            _timeRow(
              context,
              strings.eyeProtectionStartTime,
              settings.startTime,
              (value) =>
                  _save(context, () => notifier.update(startTime: value)),
            ),
            _timeRow(
              context,
              strings.eyeProtectionEndTime,
              settings.endTime,
              (value) => _save(context, () => notifier.update(endTime: value)),
            ),
          ],
        ],
      ],
    );
  }

  Future<void> _save(BuildContext context, Future<void> Function() save) async {
    try {
      await save();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('保存失败，请重试')));
      }
    }
  }

  Widget _timeRow(
    BuildContext context,
    String title,
    String value,
    Future<void> Function(String) onChanged,
  ) => SettingTile(
    title: title,
    value: value,
    showChevron: false,
    onTap: () async {
      final minute = parseEyeProtectionTime(value) ?? 0;
      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
        helpText: title,
      );
      if (picked == null) return;
      await onChanged(
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}',
      );
    },
  );
}
