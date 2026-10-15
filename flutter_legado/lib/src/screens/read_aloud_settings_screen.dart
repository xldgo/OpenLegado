import '../domain/models/read_aloud_content.dart';
import '../widgets/bottom_sheet_widget.dart';
import '../widgets/app_settings_sheet.dart';

import '../features/read_aloud/tts_cache_screen.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:material_ui/material_ui.dart';

import '../l10n/app_localization.dart';
import '../providers/audio/audio_notifier.dart';
import '../providers/audio/read_aloud_preferences.dart';
import '../providers/audio/read_aloud_capsule.dart';
import '../routes.dart';

import 'package:flutter_legado/src/platform/tts/system_tts.dart';

import '../widgets/app_scaffold.dart';
import '../widgets/legado_app_bar.dart';
import '../widgets/settings_widgets.dart';

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

  Future<String?> _chooseSplitSymbols(String current) {
    final selected = current.split('').toSet();
    return AppBottomSheet.showContent<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AppSettingsSheet(
          contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          title: context.l10n.readAloudSplitSymbolsTitle,
          onSave: selected.isEmpty
              ? null
              : () => Navigator.pop(context, selected.join()),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final symbol in readAloudSplitSymbols.split(''))
                FilterChip(
                  label: Text(symbol),
                  selected: selected.contains(symbol),
                  onSelected: (value) => update(() {
                    value ? selected.add(symbol) : selected.remove(symbol);
                  }),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    final preferences = ref.watch(readAloudPreferencesProvider);
    final capsule = ref.watch(readAloudCapsuleProvider);
    final audio = ref.watch(audioNotifierProvider);
    final notifier = ref.read(audioNotifierProvider.notifier);
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
              SettingMenuRow<ReadAloudSplitMode>(
                title: strings.readAloudSplitMode,
                value: preferences.splitMode,
                options: {
                  ReadAloudSplitMode.paragraph: strings.readAloudSplitParagraph,
                  ReadAloudSplitMode.symbols: strings.readAloudSplitSymbols,
                  ReadAloudSplitMode.page: strings.readAloudSplitPage,
                },
                onChanged: enabled
                    ? (mode) => _save(
                        () => notifier.setContentSplit(
                          mode,
                          preferences.splitSymbols,
                        ),
                      )
                    : null,
              ),
              if (preferences.splitMode == ReadAloudSplitMode.symbols)
                SettingTile(
                  title: strings.readAloudSplitSymbolsTitle,
                  subtitle: strings.readAloudSplitSymbolsHint,
                  trailing: Text(preferences.splitSymbols),
                  onTap: enabled
                      ? () async {
                          final selected = await _chooseSplitSymbols(
                            preferences.splitSymbols,
                          );
                          if (selected != null && mounted) {
                            await _save(
                              () => notifier.setContentSplit(
                                preferences.splitMode,
                                selected,
                              ),
                            );
                          }
                        }
                      : null,
                ),
              if (preferences.splitMode == ReadAloudSplitMode.page)
                SettingsSectionFooter(strings.readAloudSplitPageHint),
              SettingSwitchRow(
                title: strings.readAloudFollowSystem,
                subtitle: strings.readAloudFollowSystemSummary,
                value: preferences.followSystem,
                onChanged: enabled
                    ? (value) =>
                          _save(() => notifier.setReadAloudFollowSystem(value))
                    : null,
              ),
              SettingSwitchRow(
                title: strings.readAloudDetachReminder,
                subtitle: strings.readAloudDetachReminderSummary,
                value: preferences.detachReminder,
                onChanged: enabled
                    ? (value) => _save(
                        () => ref
                            .read(readAloudPreferencesProvider.notifier)
                            .setDetachReminder(value),
                      )
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
                        () => notifier.setReadAloudParagraphInterval(
                          (value * 1000).round(),
                        ),
                      )
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 16),
          SettingsGroup(
            title: '音频缓存',
            showDividers: false,
            children: [
              SettingStepperRow(
                title: '预下载章节数',
                value: preferences.audioPreDownloadNum.toDouble(),
                min: 0,
                max: 100,
                step: 1,
                unit: '章',
                onChanged: enabled
                    ? (v) => _save(() async {
                        await ref
                            .read(readAloudPreferencesProvider.notifier)
                            .setAudioPreDownloadNum(v.round());
                        await notifier.refreshHttpPrefetchSettings();
                      })
                    : null,
              ),
              SettingStepperRow(
                title: '预合成并发',
                value: preferences.ttsPreSynthesisConcurrency.toDouble(),
                min: 1,
                max: 8,
                step: 1,
                onChanged: enabled
                    ? (v) => _save(() async {
                        await ref
                            .read(readAloudPreferencesProvider.notifier)
                            .setTtsPreSynthesisConcurrency(v.round());
                        await notifier.refreshHttpPrefetchSettings();
                      })
                    : null,
              ),
              SettingStepperRow(
                title: '音频缓存保留时间',
                value: preferences.audioCacheCleanTime.toDouble(),
                min: 0,
                max: 1440,
                step: 1,
                unit: '分钟',
                onChanged: enabled
                    ? (v) => _save(() async {
                        await ref
                            .read(readAloudPreferencesProvider.notifier)
                            .setAudioCacheCleanTime(v.round());
                        await notifier.refreshHttpPrefetchSettings();
                      })
                    : null,
              ),
              SettingTile(
                icon: Icons.audio_file_outlined,
                title: '朗读缓存',
                subtitle: '查看音频与预合成日志，管理缓存',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const TtsCacheScreen(),
                  ),
                ),
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
              SettingTile(
                icon: Icons.record_voice_over,
                title: strings.readAloudEngines,
                subtitle: strings.readAloudEnginesSummary,
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.readAloudConfig),
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
