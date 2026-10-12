import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:material_ui/material_ui.dart';

import '../l10n/app_localization.dart';
import '../providers/audio/audio_notifier.dart';
import '../providers/audio/read_aloud_preferences.dart';
import '../providers/audio/read_aloud_capsule.dart';
import '../routes.dart';
import '../services/system_tts_service.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/legado_app_bar.dart';
import '../widgets/settings_widgets.dart';
import '../widgets/system_tts_settings_dialog.dart';

/// 朗读偏好与引擎管理分开；打开设置不重新应用或重启播放。
class ReadAloudSettingsScreen extends ConsumerStatefulWidget {
  const ReadAloudSettingsScreen({super.key});

  @override
  ConsumerState<ReadAloudSettingsScreen> createState() =>
      _ReadAloudSettingsScreenState();
}

class _ReadAloudSettingsScreenState
    extends ConsumerState<ReadAloudSettingsScreen> {
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      await ref.read(readAloudPreferencesProvider.notifier).load();
      if (mounted) setState(() => _error = null);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _save(Future<void> Function() action) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.readAloudSaveFailed('$error'))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    final preferences = ref.watch(readAloudPreferencesProvider);
    final capsule = ref.watch(readAloudCapsuleProvider);
    final audio = ref.watch(audioNotifierProvider);
    final notifier = ref.read(audioNotifierProvider.notifier);
    final system = ref.read(systemTtsServiceProvider);
    final enabled = preferences.loaded && !_saving;
    final systemActive =
        !audio.isStreamMode &&
        notifier.resolveTtsEngineUrl() == systemTtsEngineUrl;

    return AppScaffold(
      topBar: LegadoAppBar(title: Text(strings.readAloudSettingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null)
            ListTile(
              title: Text(strings.loadFailed),
              subtitle: Text(_error!),
              trailing: TextButton(
                onPressed: _load,
                child: Text(strings.retry),
              ),
            )
          else if (!preferences.loaded)
            const LinearProgressIndicator(),
          SettingsGroup(
            title: strings.readAloudPlaybackGroup,
            showDividers: false,
            children: [
              SettingSwitchRow(
                title: strings.readAloudFollowSystem,
                subtitle: strings.readAloudFollowSystemSummary,
                value: preferences.followSystem,
                onChanged: enabled
                    ? (value) =>
                          _save(() => notifier.setReadAloudFollowSystem(value))
                    : null,
              ),
              SettingStepperRow(
                title: strings.readAloudSpeed,
                value: preferences.manualSpeed,
                min: 0.5,
                max: 3,
                step: 0.1,
                unit: '×',
                onChanged: enabled && !preferences.followSystem
                    ? (value) => _save(() => notifier.setReadAloudSpeed(value))
                    : null,
              ),
              SettingStepperRow(
                title: strings.readAloudParagraphInterval,
                value: preferences.paragraphIntervalMs / 1000,
                min: 0,
                max: 5,
                step: 0.1,
                unit: strings.readAloudSecondsUnit,
                onChanged: enabled
                    ? (value) => _save(
                        () => ref
                            .read(readAloudPreferencesProvider.notifier)
                            .setParagraphInterval((value * 1000).round()),
                      )
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 16),
          SettingsGroup(
            title: strings.readAloudCapsuleGroup,
            children: [
              SettingSwitchRow(
                title: strings.readAloudCapsuleAutoCollapse,
                subtitle: strings.readAloudCapsuleAutoCollapseSummary,
                value: capsule.autoCollapse,
                onChanged: !_saving
                    ? (value) => _save(
                        () => ref
                            .read(readAloudCapsuleProvider.notifier)
                            .setAutoCollapse(value),
                      )
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 16),
          SettingsGroup(
            title: strings.readAloudVoiceGroup,
            children: [
              IosListTile(
                icon: Icons.record_voice_over,
                title: strings.readAloudEngines,
                subtitle: strings.readAloudEnginesSummary,
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.readAloudConfig),
              ),
              if (system.isSupported)
                IosListTile(
                  icon: Icons.voice_chat,
                  title: strings.readAloudSystemVoice,
                  subtitle: strings.readAloudSystemVoiceSummary,
                  onTap: () => showSystemTtsSettings(
                    context,
                    system,
                    notifier.refreshSystemTtsSettings,
                  ),
                ),
            ],
          ),
          if (systemActive) ...[
            const SizedBox(height: 16),
            SettingsGroup(
              title: strings.readAloudSystemAdjustmentGroup,
              showDividers: false,
              children: [
                SettingStepperRow(
                  title: strings.readAloudPitch,
                  value: audio.config.pitch,
                  min: 0.5,
                  max: 2,
                  step: 0.1,
                  onChanged: (value) => notifier.updateConfig(pitch: value),
                ),
                SettingStepperRow(
                  title: strings.readAloudVolume,
                  value: audio.config.volume * 100,
                  min: 0,
                  max: 100,
                  step: 10,
                  unit: '%',
                  onChanged: (value) =>
                      notifier.updateConfig(volume: value / 100),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
