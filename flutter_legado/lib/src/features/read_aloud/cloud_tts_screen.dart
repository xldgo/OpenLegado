import '../../domain/contracts/cloud_tts_provider.dart';

import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/contracts/cloud_tts_repository.dart';
import '../../providers/audio/audio_notifier.dart';
import '../../providers/providers.dart';
import '../../services/stream_audio_player.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/legado_app_bar.dart';
import '../../l10n/app_localization.dart';
import 'cloud_tts_providers.dart';
import 'cloud_tts_settings.dart';
import 'playback/cloud_read_aloud_engine.dart';
import 'playback/read_aloud_engine.dart';

/// 云端管理只收集输入、展示状态并委托窄接口。— Codex + UI
final class CloudTtsScreen extends ConsumerStatefulWidget {
  const CloudTtsScreen({super.key});
  @override
  ConsumerState<CloudTtsScreen> createState() => _CloudTtsScreenState();
}

class _CloudTtsScreenState extends ConsumerState<CloudTtsScreen> {
  List<CloudTtsEngine> _engines = [];
  bool _busy = false;
  bool _editing = false;
  String? _error;
  int _previewGeneration = 0;
  String? _previewId;
  late final StreamAudioPlayer _previewPlayer;
  CloudReadAloudEngine? _previewEngine;
  @override
  void initState() {
    super.initState();
    _previewPlayer = ref.read(cloudTtsPreviewPlayerProvider);
    unawaited(_run(_load));
  }

  Future<void> _load() async {
    final repo = ref.read(cloudTtsRepositoryProvider);
    final list = await repo.list();
    if (mounted) setState(() => _engines = list);
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await operation();
    } catch (error) {
      // 跨存储清理失败可能已提交元数据，重读实际配置再展示原始结果。
      if (mounted) {
        try {
          await _load();
        } catch (_) {}
      }
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit([CloudTtsEngine? engine]) async {
    if (_busy || _editing) return;
    _editing = true;
    try {
      final voices = await ref
          .read(cloudTtsRepositoryProvider)
          .voices(engine?.provider ?? 'openai_speech');
      if (!mounted) return;
      final result = await showDialog<({CloudTtsEngine engine, String? key})>(
        context: context,
        builder: (_) => _CloudEditDialog(
          engine: engine,
          voices: voices,
          loadVoices: ref.read(cloudTtsRepositoryProvider).voices,
        ),
      );
      if (result == null || !mounted) return;
      await _run(() async {
        await _stopPreview();
        if (!mounted) return;
        await ref
            .read(cloudTtsSettingsProvider)
            .save(result.engine, apiKey: result.key);
        if (!mounted) return;
        await _load();
        if (!mounted) return;
        final notifier = ref.read(audioNotifierProvider.notifier);
        if (notifier.resolveTtsEngineUrl() == result.engine.selection) {
          await notifier.restartCurrentTts();
        }
      });
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      _editing = false;
    }
  }

  Future<void> _delete(CloudTtsEngine engine) async {
    final l = context.l10n;
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.cloudTtsDelete),
        content: Text(l.cloudTtsDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(l.cloudTtsCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(l.cloudTtsDelete),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    await _run(() async {
      await _stopPreview();
      if (!mounted) return;
      await ref.read(cloudTtsSettingsProvider).delete(engine);
      if (!mounted) return;
      final notifier = ref.read(audioNotifierProvider.notifier);
      if (notifier.resolveTtsEngineUrl() == engine.selection) {
        notifier.pause();
        await notifier.restartCurrentTts();
      }
      if (mounted) await _load();
    });
  }

  Future<void> _stopPreview() async {
    _previewGeneration++;
    if (mounted) setState(() => _previewId = null);
    await _previewEngine?.stop();
  }

  Future<void> _preview(CloudTtsEngine engine) async {
    final l = context.l10n;
    final text = await showDialog<String>(
      context: context,
      builder: (_) => _CloudPreviewDialog(sample: l.cloudTtsSample),
    );
    if (!mounted || text == null) return;
    await _run(() async {
      await _stopPreview();
      if (!mounted) return;
      final notifier = ref.read(audioNotifierProvider.notifier);
      notifier.pause();
      await notifier.restartCurrentTts();
      if (!mounted) return;
      final synthesizer = ref.read(cloudTtsSynthesizerProvider);
      final cache = ref.read(bookApiProvider).ttsCacheRepository;
      _previewEngine ??= CloudReadAloudEngine(
        synthesizer: () => synthesizer,
        player: _previewPlayer,
        cache: () => cache,
      );
      _previewPlayer.onCompleted = _previewEngine!.handleCompleted;
      _previewPlayer.onProgress = _previewEngine!.handleProgress;
      final generation = ++_previewGeneration;
      setState(() => _previewId = engine.id);
      final session = ReadAloudSession(
        isCurrent: () => mounted && generation == _previewGeneration,
        onCompleted: () {
          unawaited(_stopPreview());
        },
        onProgress: (_) {},
        onError: (error) {
          if (mounted) setState(() => _error = '$error');
          unawaited(_stopPreview());
        },
      );
      ReadAloudStart result;
      try {
        result = await _previewEngine!.speak(
          ReadAloudRequest(text: text, engineUrl: engine.selection),
          session,
        );
      } catch (_) {
        await _stopPreview();
        rethrow;
      }
      if (result == ReadAloudStart.noAudio) {
        await _stopPreview();
        throw StateError('当前环境未生成云端试听音频');
      }
    });
  }

  @override
  void dispose() {
    _previewGeneration++;
    unawaited(
      (_previewEngine?.stop() ?? Future<void>.value()).then(
        (_) => _previewPlayer.dispose(),
      ),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AppScaffold(
      topBar: LegadoAppBar(
        title: Text(l.cloudTtsTitle),
        actions: [
          IconButton(
            tooltip: l.cloudTtsAdd,
            onPressed: _busy ? null : () => _edit(),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Padding(padding: const EdgeInsets.all(16), child: Text(_error!)),
          if (_previewId != null)
            TextButton.icon(
              onPressed: _stopPreview,
              icon: const Icon(Icons.stop),
              label: Text(l.cloudTtsStop),
            ),
          Expanded(
            child: _engines.isEmpty
                ? Center(child: Text(l.cloudTtsEmpty))
                : ListView(
                    children: [
                      for (final engine in _engines)
                        ListTile(
                          title: Text(engine.name),
                          subtitle: Text(
                            '${cloudTtsProfile(engine.provider).name} · ${engine.model}',
                          ),
                          onTap: _busy ? null : () => _edit(engine),
                          trailing: PopupMenuButton<String>(
                            enabled: !_busy,
                            onSelected: (action) {
                              if (action == 'preview') {
                                unawaited(_preview(engine));
                              } else if (action == 'delete') {
                                unawaited(_delete(engine));
                              } else {
                                unawaited(
                                  _run(() async {
                                    final notifier = ref.read(
                                      audioNotifierProvider.notifier,
                                    );
                                    if (action == 'book') {
                                      if (!await notifier.setBookTtsEngine(
                                        engine.selection,
                                      )) {
                                        throw StateError('未打开书籍，无法设置本书引擎');
                                      }
                                    } else {
                                      await notifier.setGlobalTtsEngine(
                                        engine.selection,
                                      );
                                    }
                                  }),
                                );
                              }
                            },
                            itemBuilder: (_) => [
                              if (engine.enabled)
                                PopupMenuItem(
                                  value: 'preview',
                                  child: Text(l.cloudTtsPreview),
                                ),
                              if (engine.enabled)
                                PopupMenuItem(
                                  value: 'book',
                                  child: Text(l.cloudTtsBook),
                                ),
                              if (engine.enabled)
                                PopupMenuItem(
                                  value: 'global',
                                  child: Text(l.cloudTtsGlobal),
                                ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(l.cloudTtsDelete),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _CloudPreviewDialog extends StatefulWidget {
  const _CloudPreviewDialog({required this.sample});
  final String sample;
  @override
  State<_CloudPreviewDialog> createState() => _CloudPreviewDialogState();
}

class _CloudPreviewDialogState extends State<_CloudPreviewDialog> {
  late final _text = TextEditingController(text: widget.sample);
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.cloudTtsPreview),
      content: TextField(
        controller: _text,
        maxLines: 3,
        decoration: InputDecoration(labelText: l.cloudTtsPreviewText),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cloudTtsCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _text.text),
          child: Text(l.cloudTtsPreview),
        ),
      ],
    );
  }
}

class _CloudEditDialog extends StatefulWidget {
  const _CloudEditDialog({
    this.engine,
    required this.voices,
    required this.loadVoices,
  });
  final CloudTtsEngine? engine;
  final List<String> voices;
  final Future<List<String>> Function(String) loadVoices;
  @override
  State<_CloudEditDialog> createState() => _CloudEditDialogState();
}

class _CloudEditDialogState extends State<_CloudEditDialog> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _inputs;
  bool _enabled = true;
  String _format = 'mp3';
  late String _provider;
  late List<String> _voices;
  bool _loadingVoices = false;
  String? _voiceError;
  int _voiceGeneration = 0;
  @override
  void initState() {
    super.initState();
    final engine = widget.engine;
    final options = engine?.options ?? {};
    _provider = engine?.provider ?? 'openai_speech';
    _voices = widget.voices;
    final profile = cloudTtsProfile(_provider);
    _enabled = engine?.enabled ?? true;
    _format = options['format'] as String? ?? profile.formats.first;
    _inputs = {
      for (final entry in <String, String>{
        'name': engine?.name ?? profile.name,
        'baseUrl': engine?.baseUrl ?? '',
        'model': engine?.model ?? profile.model,
        'apiKey': '',
        'voiceId': options['voiceId'] as String? ?? profile.voice,
        'speed': '${options['speed'] ?? 1.0}',
        'style': options['style'] as String? ?? '',
        'instructions': options['instructions'] as String? ?? '',
      }.entries)
        entry.key: TextEditingController(text: entry.value),
    };
  }

  Future<void> _changeProvider(String? provider) async {
    if (provider == null || provider == _provider || widget.engine != null) {
      return;
    }
    final old = cloudTtsProfile(_provider);
    final next = cloudTtsProfile(provider);
    final generation = ++_voiceGeneration;
    setState(() {
      _provider = provider;
      _format = next.formats.first;
      _voices = [];
      _loadingVoices = true;
      _voiceError = null;
      if (_inputs['name']!.text == old.name) _inputs['name']!.text = next.name;
      _inputs['model']!.text = next.model;
      _inputs['voiceId']!.text = next.voice;
      _inputs['speed']!.text = '1.0';
      _inputs['style']!.clear();
      _inputs['instructions']!.clear();
      // 新建期间也不能将前一家输入的密钥沿用到另一服务商。
      _inputs['apiKey']!.clear();
      _inputs['baseUrl']!.clear();
    });
    try {
      final voices = await widget.loadVoices(provider);
      if (mounted && generation == _voiceGeneration) {
        setState(() => _voices = voices);
      }
    } catch (error) {
      if (mounted && generation == _voiceGeneration) {
        setState(() => _voiceError = '$error');
      }
    } finally {
      if (mounted && generation == _voiceGeneration) {
        setState(() => _loadingVoices = false);
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _inputs.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final labels = {
      'name': l.cloudTtsName,
      'baseUrl': l.cloudTtsBaseUrl,
      'model': l.cloudTtsModel,
      'apiKey': l.cloudTtsApiKey,
      'voiceId': l.cloudTtsVoice,
      'speed': l.cloudTtsSpeed,
      'style': l.cloudTtsStyle,
      'instructions': l.cloudTtsInstructions,
    };
    return AlertDialog(
      title: Text(widget.engine == null ? l.cloudTtsAdd : l.cloudTtsEdit),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  key: const ValueKey('cloud-provider'),
                  initialValue: _provider,
                  decoration: InputDecoration(labelText: l.cloudTtsProvider),
                  items: [
                    for (final entry in cloudTtsProviderProfiles.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value.name),
                      ),
                  ],
                  onChanged: widget.engine == null ? _changeProvider : null,
                ),
                if (_loadingVoices) const LinearProgressIndicator(),
                if (_voiceError != null)
                  Text('${l.cloudTtsVoiceLoadFailed}: $_voiceError'),
                for (final entry in _inputs.entries)
                  if (entry.key != 'speed' || _provider != 'mimo')
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        key: ValueKey('cloud-${entry.key}'),
                        controller: entry.value,
                        decoration: InputDecoration(
                          labelText: labels[entry.key],
                        ),
                        obscureText: entry.key == 'apiKey',
                        enableSuggestions: entry.key != 'apiKey',
                        autocorrect: entry.key != 'apiKey',
                        enableIMEPersonalizedLearning: entry.key != 'apiKey',
                        validator: (value) {
                          if ({
                                'name',
                                'model',
                                'voiceId',
                              }.contains(entry.key) &&
                              (value ?? '').trim().isEmpty) {
                            return labels[entry.key];
                          }
                          if (entry.key == 'apiKey' &&
                              widget.engine == null &&
                              (value ?? '').trim().isEmpty) {
                            return l.cloudTtsApiKey;
                          }
                          if (entry.key == 'speed') {
                            final speed = double.tryParse(value ?? '');
                            if (speed == null ||
                                !speed.isFinite ||
                                speed < 0.25 ||
                                speed > 4) {
                              return '0.25–4.0';
                            }
                          }
                          return null;
                        },
                      ),
                    ),
                Wrap(
                  spacing: 4,
                  children: [
                    for (final voice in _voices)
                      ActionChip(
                        label: Text(voice),
                        onPressed: () => _inputs['voiceId']!.text = voice,
                      ),
                  ],
                ),
                if (cloudTtsProfile(_provider).styles.isNotEmpty)
                  Wrap(
                    spacing: 4,
                    children: [
                      for (final style in cloudTtsProfile(_provider).styles)
                        ActionChip(
                          label: Text(style),
                          onPressed: () => _inputs['style']!.text = style,
                        ),
                    ],
                  ),
                DropdownMenu<String>(
                  key: ValueKey('cloud-format-$_provider'),
                  label: Text(l.cloudTtsFormat),
                  initialSelection: _format,
                  dropdownMenuEntries: [
                    for (final format in cloudTtsProfile(_provider).formats)
                      DropdownMenuEntry(value: format, label: format),
                  ],
                  onSelected: (v) {
                    if (v != null) _format = v;
                  },
                ),
                SwitchListTile(
                  title: Text(l.cloudTtsEnabled),
                  value: _enabled,
                  onChanged: (v) => setState(() => _enabled = v),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cloudTtsCancel),
        ),
        FilledButton(
          onPressed: () {
            if (_loadingVoices ||
                _voiceError != null ||
                !_form.currentState!.validate()) {
              return;
            }
            final old = widget.engine;
            final engine = CloudTtsEngine(
              id: old?.id ?? randomCloudTtsId(),
              provider: _provider,
              name: _inputs['name']!.text.trim(),
              baseUrl: _inputs['baseUrl']!.text.trim(),
              model: _inputs['model']!.text.trim(),
              enabled: _enabled,
              createdAt: old?.createdAt ?? 0,
              updatedAt: old?.updatedAt ?? 0,
              credentialKey: old?.credentialKey ?? '',
              region: old?.region ?? '',
              appId: old?.appId ?? '',
              optionsJson: jsonEncode({
                'voiceId': _inputs['voiceId']!.text.trim(),
                if (_provider != 'mimo')
                  'speed': double.parse(_inputs['speed']!.text),
                'style': _inputs['style']!.text,
                'instructions': _inputs['instructions']!.text,
                'format': _format,
              }),
            );
            final key = _inputs['apiKey']!.text;
            Navigator.pop(context, (
              engine: engine,
              key: key.trim().isEmpty ? null : key,
            ));
          },
          child: Text(l.cloudTtsSave),
        ),
      ],
    );
  }
}
