import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/contracts/read_aloud_voice_repository.dart';
import '../../providers/providers.dart';
import '../../providers/audio/audio_notifier.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/legado_app_bar.dart';
import 'http_tts_voice_selection.dart';
import 'read_aloud_voice_provider.dart';
import 'tts_providers.dart';

class ReadAloudVoiceScreen extends ConsumerStatefulWidget {
  const ReadAloudVoiceScreen({super.key});
  @override
  ConsumerState<ReadAloudVoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends ConsumerState<ReadAloudVoiceScreen> {
  bool _showExcluded = false, _busy = false;
  String? _error;
  Map<String, HttpTtsVoiceSelection> _selections = {};
  int _refreshGeneration = 0;
  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final generation = ++_refreshGeneration;
    final system = ref.read(systemTtsServiceProvider);
    try {
      if (system.isSupported) {
        await ref.read(readAloudVoicesProvider.notifier).discoverSystem(system);
      }
      if (!mounted || generation != _refreshGeneration) return;
      final voices = await ref.read(readAloudVoicesProvider.future);
      if (!mounted || generation != _refreshGeneration) return;
      final api = ref.read(bookApiProvider);
      final selections = <String, HttpTtsVoiceSelection>{};
      for (final engine
          in voices
              .where((v) => v.engineType == 'http')
              .map((v) => v.engineId)
              .toSet()) {
        final selection = HttpTtsVoiceSelection.decode(
          await api.getConfig(HttpTtsVoiceSelection.key(int.parse(engine))),
        );
        if (selection != null) selections[engine] = selection;
      }
      if (mounted && generation == _refreshGeneration) {
        setState(() {
          _selections = selections;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted && generation == _refreshGeneration) {
        setState(() => _error = '音色读取失败：$error');
      }
    }
  }

  bool _selected(ReadAloudVoice voice) {
    if (voice.engineType == 'http') {
      return _selections[voice.engineId]?.voiceId == voice.id;
    }
    final system = ref.read(systemTtsServiceProvider);
    final traits = jsonDecode(voice.traitsJson) as Map<String, dynamic>;
    return voice.engineId == 'system:${system.selectedEngine}' &&
        traits['voiceKey'] == system.selectedVoice;
  }

  Future<void> _action(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await operation();
      if (mounted) setState(() => _error = null);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _flags(
    ReadAloudVoice voice, {
    bool? enabled,
    bool? excluded,
  }) async {
    await ref
        .read(readAloudVoicesProvider.notifier)
        .setFlags(voice, enabled: enabled, excluded: excluded);
    if (!mounted) return;
    final notifier = ref.read(audioNotifierProvider.notifier);
    if (voice.engineType == 'http' &&
        await notifier.resolveTtsEngineId() == int.tryParse(voice.engineId)) {
      await notifier.restartCurrentTts();
    } else if (voice.engineType == 'system' &&
        notifier.resolveTtsEngineUrl() == 'system://default') {
      final traits = jsonDecode(voice.traitsJson) as Map<String, dynamic>;
      final system = ref.read(systemTtsServiceProvider);
      if (system.selectedVoice == traits['voiceKey'] &&
          ((enabled == false) || (excluded == true))) {
        // 保留用户选择；重新起播时报告不可用，不替换为另一音色。
        await system.stop();
        await notifier.refreshSystemTtsSettings();
      }
    }
  }

  Future<void> _choose(ReadAloudVoice voice) async {
    if (!voice.selectable) return;
    final notifier = ref.read(audioNotifierProvider.notifier);
    if (voice.engineType == 'system') {
      final traits = jsonDecode(voice.traitsJson) as Map<String, dynamic>;
      await ref
          .read(systemTtsServiceProvider)
          .saveSettings(
            engine: voice.engineId.substring('system:'.length),
            voice: traits['voiceKey'] as String,
          );
      await notifier.refreshSystemTtsSettings();
    } else {
      final emotions = (jsonDecode(voice.emotionCatalogJson) as List)
          .cast<Map>();
      final selection = HttpTtsVoiceSelection.decode(
        await ref
            .read(bookApiProvider)
            .getConfig(HttpTtsVoiceSelection.key(int.parse(voice.engineId))),
      );
      String? emotion = selection?.voiceId == voice.id
          ? selection?.emotionTag
          : null;
      if (emotions.isNotEmpty && mounted) {
        final chosen = await showDialog<String>(
          context: context,
          builder: (c) => SimpleDialog(
            title: Text('${voice.displayName} · 情感'),
            children: [
              SimpleDialogOption(
                onPressed: () => Navigator.pop(c, ''),
                child: const Text('默认情感'),
              ),
              for (final e in emotions)
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(c, e['emotionTag'] as String),
                  child: Text(e['emotionName'] as String),
                ),
            ],
          ),
        );
        if (chosen == null) return;
        emotion = chosen.isEmpty ? null : chosen;
      }
      await notifier.setHttpTtsVoice(
        int.parse(voice.engineId),
        voice,
        emotionTag: emotion,
      );
      if (mounted) {
        _refreshGeneration++;
        _selections[voice.engineId] = HttpTtsVoiceSelection(
          voice.id,
          emotionTag: emotion,
        );
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('音色已保存')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(readAloudVoicesProvider);
    return AppScaffold(
      topBar: LegadoAppBar(
        title: const Text('朗读音色'),
        actions: [
          IconButton(
            tooltip: '刷新音色',
            onPressed: _busy
                ? null
                : () async {
                    await _refresh();
                    if (mounted) {
                      await ref.read(readAloudVoicesProvider.notifier).reload();
                    }
                  },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          SwitchListTile(
            title: const Text('显示已排除音色'),
            value: _showExcluded,
            onChanged: (v) => setState(() => _showExcluded = v),
          ),
          if (_error != null)
            Padding(padding: const EdgeInsets.all(16), child: Text(_error!)),
          Expanded(
            child: catalog.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('目录读取失败：$e')),
              data: (voices) {
                final visible = voices
                    .where((v) => _showExcluded || !v.excluded)
                    .toList();
                return visible.isEmpty
                    ? const Center(
                        child: Text('暂无音色目录，请导入带发音人目录的 HTTP 源或安装系统语音'),
                      )
                    : ListView(
                        children: [
                          for (final voice in visible)
                            ListTile(
                              title: Text(voice.displayName),
                              subtitle: Text(
                                '${voice.engineType == 'system' ? '系统' : 'HTTP'} · ${voice.engineId}${voice.available ? '' : ' · 不可用'}${voice.excluded ? ' · 已排除' : ''}${_selected(voice) ? ' · 已选择' : ''}',
                              ),
                              onTap: voice.selectable && !_busy
                                  ? () => _action(() => _choose(voice))
                                  : null,
                              leading: Switch(
                                value: voice.enabled,
                                onChanged: _busy
                                    ? null
                                    : (v) => _action(
                                        () => _flags(voice, enabled: v),
                                      ),
                              ),
                              trailing: PopupMenuButton<String>(
                                enabled: !_busy,
                                onSelected: (v) => _action(() async {
                                  if (v == 'exclude') {
                                    await _flags(
                                      voice,
                                      excluded: !voice.excluded,
                                    );
                                  } else if (v == 'default') {
                                    await ref
                                        .read(audioNotifierProvider.notifier)
                                        .setHttpTtsVoice(
                                          int.parse(voice.engineId),
                                          null,
                                        );
                                    if (mounted) {
                                      _refreshGeneration++;
                                      _selections.remove(voice.engineId);
                                    }
                                  }
                                }),
                                itemBuilder: (_) => [
                                  PopupMenuItem(
                                    value: 'exclude',
                                    child: Text(
                                      voice.excluded ? '恢复音色' : '排除音色',
                                    ),
                                  ),
                                  if (voice.engineType == 'http')
                                    const PopupMenuItem(
                                      value: 'default',
                                      child: Text('使用引擎默认音色'),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      );
              },
            ),
          ),
        ],
      ),
    );
  }
}
