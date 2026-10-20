import '../../providers/domain_config_provider.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/contracts/read_aloud_voice_repository.dart';
import '../audio/application/audio_notifier.dart';
import '../../domain/contracts/cloud_tts_repository.dart';
import '../../domain/contracts/cloud_tts_provider.dart';
import 'http_tts_repository_provider.dart';
import 'read_aloud_voice_sheet.dart';
import 'read_aloud_voice_preview.dart';
import '../../widgets/bottom_sheet_widget.dart';
import 'cloud_tts_providers.dart';
import 'http_tts_voice_selection.dart';
import 'read_aloud_voice_provider.dart';
import 'tts_providers.dart';

class ReadAloudVoicePanel extends ConsumerStatefulWidget {
  const ReadAloudVoicePanel({super.key, this.revision = 0});
  final int revision;
  @override
  ReadAloudVoicePanelState createState() => ReadAloudVoicePanelState();
}

class ReadAloudVoicePanelState extends ConsumerState<ReadAloudVoicePanel> {
  late final ReadAloudVoicePreview _preview;
  String? _previewId;
  bool _disposing = false;
  Map<String, String> _cloudSelections = {};
  bool _showExcluded = false, _busy = false;
  List<({CloudTtsEngine engine, List<String> voices})> _cloudVoices = [];
  String? _cloudError;
  String? _error;
  Map<String, HttpTtsVoiceSelection> _selections = {};
  int _refreshGeneration = 0;
  @override
  void initState() {
    super.initState();
    _preview = ReadAloudVoicePreview(
      player: ref.read(cloudTtsPreviewPlayerProvider),
      system: ref.read(systemTtsServiceProvider),
      cloud: () => ref.read(cloudTtsSynthesizerProvider),
      engines: () => ref.read(cloudTtsRepositoryProvider),
      http: () => ref.read(httpTtsSynthesizerProvider),
      cache: () => ref.read(ttsCacheRepositoryProvider),
      onChanged: (id) {
        if (mounted && !_disposing) setState(() => _previewId = id);
      },
      onError: (e) {
        if (mounted && !_disposing) setState(() => _error = '$e');
      },
    );
    unawaited(_refresh());
  }

  @override
  void dispose() {
    _disposing = true;
    _refreshGeneration++;
    unawaited(_preview.dispose());
    super.dispose();
  }

  Future<void> stopPreview() => _preview.stop();
  Future<void> _previewVoice(
    ReadAloudVoice voice,
    String text, {
    bool draft = false,
  }) async {
    final notifier = ref.read(audioNotifierProvider.notifier);
    notifier.pause();
    await notifier.restartCurrentTts();
    if (!mounted || _disposing) return;
    await _preview.speak(
      voice,
      text,
      draft: draft,
      httpSelection: !draft && voice.engineType == 'http'
          ? _selections[voice.engineId]
          : null,
    );
  }

  Future<void> addVoice() => _action(() async {
    await stopPreview();
    final voices = await ref.read(readAloudVoicesProvider.future);
    final sources = <VoiceEditorSource>[
      for (final entry in _cloudVoices)
        VoiceEditorSource(
          kind: 'cloud_tts',
          id: entry.engine.id,
          name: entry.engine.name,
          provider: entry.engine.provider,
          voices: [
            for (final speaker in entry.voices)
              ReadAloudVoice(
                id: readAloudVoiceId('cloud_tts', entry.engine.id, speaker),
                engineType: 'cloud_tts',
                engineId: entry.engine.id,
                speakerId: speaker,
                displayName: speaker,
                traitsJson: '{}',
              ),
          ],
        ),
      for (final engine
          in await ref.read(httpTtsRepositoryProvider).getHttpTts())
        if (engine.isEnabled)
          VoiceEditorSource(
            kind: 'http',
            id: '${engine.id}',
            name: engine.name,
            voices: voices
                .where(
                  (v) =>
                      v.engineType == 'http' &&
                      v.engineId == '${engine.id}' &&
                      v.available,
                )
                .toList(),
          ),
    ];
    final system = ref.read(systemTtsServiceProvider);
    if (system.isSupported) {
      sources.add(
        VoiceEditorSource(
          kind: 'system',
          id: 'system:${system.selectedEngine}',
          name: '系统 TTS',
          voices: voices
              .where(
                (v) =>
                    v.engineType == 'system' &&
                    v.engineId == 'system:${system.selectedEngine}' &&
                    v.available,
              )
              .toList(),
        ),
      );
    }
    if (!mounted) return;
    if (sources.isEmpty) throw StateError('请先添加朗读引擎');
    final source = await AppBottomSheet.showContent<VoiceEditorSource>(
      context: context,
      showDragHandle: true,
      builder: (c) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(c).height * .75,
        ),
        child: AppBottomSheet.content(
          title: '选择引擎',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final source in sources)
                ListTile(
                  title: Text(source.name),
                  subtitle: Text(
                    source.kind == 'cloud_tts'
                        ? '云 TTS'
                        : source.kind == 'http'
                        ? 'HTTP 协议 TTS'
                        : '系统 TTS',
                  ),
                  onTap: () => Navigator.pop(c, source),
                ),
            ],
          ),
        ),
      ),
    );
    if (source != null && mounted) await _editVoice(source);
  });
  Future<void> _editVoice(
    VoiceEditorSource source, [
    ReadAloudVoice? voice,
  ]) async {
    await stopPreview();
    if (!mounted) return;
    final engine = _cloudVoices
        .where((e) => e.engine.id == source.id)
        .firstOrNull
        ?.engine;
    final editorSource =
        source.kind == 'cloud_tts' &&
            engine != null &&
            (cloudTtsProfile(engine.provider).remoteCatalog ||
                cloudTtsProfile(engine.provider).staticVoiceDescriptors)
        ? VoiceEditorSource(
            kind: source.kind,
            id: source.id,
            name: source.name,
            provider: source.provider,
            voices: source.voices,
            loadCatalog: (cancel) =>
                ref.read(cloudTtsVoiceCatalogProvider).discover(engine, cancel),
          )
        : source;
    final result = await AppBottomSheet.showContent<ReadAloudVoice>(
      context: context,
      showDragHandle: true,
      builder: (_) => ReadAloudVoiceSheet(
        source: editorSource,
        voice: voice,
        httpEmotionTag:
            voice != null && _selections[voice.engineId]?.voiceId == voice.id
            ? _selections[voice.engineId]?.emotionTag
            : null,
        onPreview: (voice, text) => _previewVoice(voice, text, draft: true),
        onStop: stopPreview,
      ),
    );
    await stopPreview();
    if (result == null || !mounted) return;
    await ref.read(readAloudVoiceRepositoryProvider).save(result);
    if (!mounted) return;
    final selectedHttp =
        result.engineType == 'http' &&
        _selections[result.engineId]?.voiceId == result.id;
    if (selectedHttp) {
      await ref
          .read(audioNotifierProvider.notifier)
          .setHttpTtsVoice(int.parse(result.engineId), result);
      if (!mounted) return;
    }
    await ref.read(readAloudVoicesProvider.notifier).reload();
    await _refresh();
    if (!mounted) return;
    final notifier = ref.read(audioNotifierProvider.notifier);
    if (result.engineType == 'cloud_tts' &&
        notifier.resolveTtsEngineUrl() == 'cloud://${result.engineId}' &&
        _cloudSelections[result.engineId] == result.id) {
      await notifier.restartCurrentTts();
    } else if (!selectedHttp &&
        result.engineType == 'http' &&
        await notifier.resolveTtsEngineId() == int.tryParse(result.engineId)) {
      await notifier.restartCurrentTts();
    }
  }

  Future<void> _editExisting(ReadAloudVoice voice) async {
    final entry = _cloudVoices
        .where((e) => e.engine.id == voice.engineId)
        .firstOrNull;
    await _editVoice(
      VoiceEditorSource(
        kind: voice.engineType,
        id: voice.engineId,
        name: entry?.engine.name ?? voice.engineId,
        voices: [voice],
        provider: entry?.engine.provider,
      ),
      voice,
    );
  }

  Future<void> _deleteVoice(ReadAloudVoice voice) async {
    await stopPreview();
    if (!mounted) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('删除音色'),
        content: Text('确定删除「${voice.displayName}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    await ref.read(readAloudVoiceRepositoryProvider).delete(voice.id);
    if (!mounted) return;
    final notifier = ref.read(audioNotifierProvider.notifier);
    if (voice.engineType == 'cloud_tts' &&
        _cloudSelections[voice.engineId] == voice.id) {
      await notifier.setCloudTtsVoice(voice.engineId, null);
    } else if (voice.engineType == 'http' &&
        _selections[voice.engineId]?.voiceId == voice.id) {
      await notifier.setHttpTtsVoice(int.parse(voice.engineId), null);
    }
    await ref.read(readAloudVoicesProvider.notifier).reload();
    if (mounted) await _refresh();
  }

  @override
  void didUpdateWidget(covariant ReadAloudVoicePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision) unawaited(_refresh());
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
      final selectionsRepository = ref.read(
        readAloudSelectionRepositoryProvider,
      );
      final cloudSelections = <String, String>{};
      for (final engine
          in voices
              .where((v) => v.engineType == 'cloud_tts')
              .map((v) => v.engineId)
              .toSet()) {
        final id = await selectionsRepository.getCloudVoice(engine);
        if (id != null && id.isNotEmpty) cloudSelections[engine] = id;
      }
      final selections = <String, HttpTtsVoiceSelection>{};
      for (final engine
          in voices
              .where((v) => v.engineType == 'http')
              .map((v) => v.engineId)
              .toSet()) {
        final selection = await selectionsRepository.getHttpVoice(
          int.parse(engine),
        );
        if (selection != null) selections[engine] = selection;
      }
      if (mounted && generation == _refreshGeneration) {
        setState(() {
          _selections = selections;
          _cloudSelections = cloudSelections;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted && generation == _refreshGeneration) {
        setState(() => _error = '音色读取失败：$error');
      }
    }
    if (mounted && generation == _refreshGeneration) {
      await _refreshCloudVoices(generation);
    }
  }

  Future<void> _refreshCloudVoices(int generation) async {
    try {
      final repository = ref.read(cloudTtsRepositoryProvider);
      final engines = await repository.list();
      final entries = <({CloudTtsEngine engine, List<String> voices})>[];
      for (final engine in engines.where((e) => e.enabled)) {
        entries.add((
          engine: engine,
          voices: cloudTtsProfile(engine.provider).remoteCatalog
              ? <String>[]
              : await repository.voices(engine.provider),
        ));
        if (!mounted || generation != _refreshGeneration) return;
      }
      if (mounted && generation == _refreshGeneration) {
        setState(() {
          _cloudVoices = entries;
          _cloudError = null;
        });
      }
    } catch (error) {
      if (mounted && generation == _refreshGeneration) {
        setState(() => _cloudError = '云端音色读取失败：$error');
      }
    }
  }

  Future<void> _chooseCloudVoice(ReadAloudVoice voice) async {
    final current = await ref
        .read(cloudTtsRepositoryProvider)
        .get(voice.engineId);
    if (current == null || !current.enabled) throw StateError('云端引擎不存在或已停用');
    await ref
        .read(audioNotifierProvider.notifier)
        .setCloudTtsVoice(voice.engineId, voice);
    if (mounted) setState(() => _cloudSelections[voice.engineId] = voice.id);
  }

  bool _selected(ReadAloudVoice voice) {
    if (voice.engineType == 'cloud_tts') {
      return _cloudSelections[voice.engineId] == voice.id;
    }
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
    if (_previewId == voice.id && (enabled == false || excluded == true)) {
      await stopPreview();
    }
    if (voice.engineType == 'cloud_tts' &&
        notifier.resolveTtsEngineUrl() == 'cloud://${voice.engineId}' &&
        _cloudSelections[voice.engineId] == voice.id) {
      await notifier.restartCurrentTts();
    } else if (voice.engineType == 'http' &&
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
    await stopPreview();
    if (!mounted) return;
    final notifier = ref.read(audioNotifierProvider.notifier);
    if (voice.engineType == 'cloud_tts') {
      await _chooseCloudVoice(voice);
    } else if (voice.engineType == 'system') {
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
      final selection = await ref
          .read(readAloudSelectionRepositoryProvider)
          .getHttpVoice(int.parse(voice.engineId));
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
        // 空字符串保留用户明确选择默认情感，null 才表示跟随音色预设。
        emotion = chosen;
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
    ref.watch(cloudTtsPreviewPlayerProvider);
    final catalog = ref.watch(readAloudVoicesProvider);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SwitchListTile(
                title: const Text('显示已排除音色'),
                value: _showExcluded,
                onChanged: (v) => setState(() => _showExcluded = v),
              ),
            ),
            IconButton(
              tooltip: '刷新音色',
              icon: const Icon(Icons.refresh),
              onPressed: _busy
                  ? null
                  : () async {
                      await ref.read(readAloudVoicesProvider.notifier).reload();
                      if (mounted) await _refresh();
                    },
            ),
          ],
        ),
        if (_previewId != null)
          TextButton.icon(
            onPressed: stopPreview,
            icon: const Icon(Icons.stop),
            label: const Text('停止试听'),
          ),
        if (_error != null)
          Padding(padding: const EdgeInsets.all(16), child: Text(_error!)),
        if (_cloudError != null)
          Padding(padding: const EdgeInsets.all(16), child: Text(_cloudError!)),
        Expanded(
          child: catalog.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('目录读取失败：$e')),
            data: (voices) {
              // 系统目录只作为添加候选；主列表展示用户保存的音色。— Codex + UI
              final visible = voices
                  .where(
                    (v) => v.engineType != 'system' || v.managedBy == 'user',
                  )
                  .where((v) => _showExcluded || !v.excluded)
                  .toList();
              return visible.isEmpty
                  ? const Center(child: Text('暂无音色，请点击右下角添加音色'))
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 100),
                      children: [
                        for (final voice in visible)
                          ListTile(
                            key: ValueKey('voice-${voice.id}'),
                            selected: _selected(voice),
                            title: Text(voice.displayName),
                            subtitle: Text(
                              '${voice.engineType == 'system'
                                  ? '系统'
                                  : voice.engineType == 'cloud_tts'
                                  ? '云 TTS'
                                  : 'HTTP'} · ${_cloudVoices.where((e) => e.engine.id == voice.engineId).firstOrNull?.engine.name ?? voice.engineId}${voice.available ? '' : ' · 不可用'}${voice.excluded ? ' · 已排除' : ''}${_selected(voice) ? ' · 已选择' : ''}',
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
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: '试听',
                                  icon: const Icon(Icons.play_arrow),
                                  onPressed: voice.selectable && !_busy
                                      ? () => _action(
                                          () => _previewVoice(
                                            voice,
                                            '这是朗读试听。欢迎使用开源阅读。',
                                          ),
                                        )
                                      : null,
                                ),
                                PopupMenuButton<String>(
                                  enabled: !_busy,
                                  onSelected: (v) => _action(() async {
                                    if (v == 'edit') {
                                      await _editExisting(voice);
                                    } else if (v == 'delete') {
                                      await _deleteVoice(voice);
                                    } else if (v == 'exclude') {
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
                                    if (voice.managedBy == 'user') ...[
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Text('编辑音色'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Text('删除音色'),
                                      ),
                                    ],
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
                              ],
                            ),
                          ),
                      ],
                    );
            },
          ),
        ),
      ],
    );
  }
}
