import 'dart:convert';
import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../domain/contracts/read_aloud_voice_repository.dart';
import '../../domain/contracts/cloud_tts_provider.dart';
import '../../domain/contracts/cloud_tts_voice_catalog.dart';
import '../../domain/contracts/http_tts_synthesizer.dart';
import '../../domain/models/http_tts_voice_options.dart';
import '../../widgets/app_settings_sheet.dart';
import '../../widgets/app_settings_form.dart';

/// 编辑器的只读引擎快照，既不包含凭据也不承担保存。— Codex + UI
final class VoiceEditorSource {
  const VoiceEditorSource({
    required this.kind,
    required this.id,
    required this.name,
    required this.voices,
    this.provider,
    this.loadCatalog,
  });
  final String kind, id, name;
  final String? provider;
  final List<ReadAloudVoice> voices;
  final Future<List<CloudTtsVoiceDescriptor>> Function(HttpTtsCancellation)?
  loadCatalog;
}

class ReadAloudVoiceSheet extends StatefulWidget {
  const ReadAloudVoiceSheet({
    super.key,
    required this.source,
    this.voice,
    this.httpEmotionTag,
    required this.onPreview,
    required this.onStop,
  });
  final VoiceEditorSource source;
  final ReadAloudVoice? voice;
  final String? httpEmotionTag;
  final Future<void> Function(ReadAloudVoice, String) onPreview;
  final Future<void> Function() onStop;
  @override
  State<ReadAloudVoiceSheet> createState() => _VoiceSheetState();
}

class _VoiceSheetState extends State<ReadAloudVoiceSheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _speaker,
      _name,
      _speed,
      _style,
      _instructions,
      _sample,
      _emotion,
      _locale,
      _role,
      _pitch,
      _volume;
  late List<ReadAloudVoice> _voices;
  List<CloudTtsVoiceDescriptor> _catalog = [];
  late final TextEditingController _sampleRate;
  HttpTtsCancellation? _catalogRequest;
  bool _loadingCatalog = false;
  String? _catalogError;
  String _format = 'wav';
  bool _previewing = false;
  String? _error;
  Map<String, dynamic> _traits = {};
  @override
  void initState() {
    super.initState();
    _voices = widget.source.voices;
    final preferred = widget.source.kind == 'system'
        ? widget.source.voices.where((v) {
            final traits = jsonDecode(v.traitsJson);
            return traits is Map &&
                (traits['locale'] as String? ?? '')
                    .toLowerCase()
                    .replaceAll('_', '-')
                    .startsWith('zh');
          }).firstOrNull
        : null;
    final voice = widget.voice ?? preferred ?? widget.source.voices.firstOrNull;
    final decoded = voice == null ? null : jsonDecode(voice.traitsJson);
    if (decoded is Map) _traits = Map<String, dynamic>.from(decoded);
    if (widget.source.kind == 'http' && voice != null) {
      _traits = HttpTtsVoiceOptions(voice.traitsJson).values;
    }
    _speaker = TextEditingController(text: voice?.speakerId ?? '');
    _name = TextEditingController(text: voice?.displayName ?? '');
    _speed = TextEditingController(text: '${_traits['speed'] ?? 1.0}');
    _locale = TextEditingController(text: _traits['locale'] as String? ?? '');
    _role = TextEditingController(text: _traits['role'] as String? ?? '');
    _sampleRate = TextEditingController(text: '${_traits['sampleRate'] ?? ''}');
    _pitch = TextEditingController(text: '${_traits['pitch'] ?? 1.0}');
    _volume = TextEditingController(text: '${_traits['volume'] ?? 1.0}');
    _style = TextEditingController(text: _traits['style'] as String? ?? '');
    _instructions = TextEditingController(
      text: _traits['instructions'] as String? ?? '',
    );
    _sample = TextEditingController(text: '这是朗读试听。欢迎使用开源阅读。');
    _emotion = TextEditingController(
      text: widget.httpEmotionTag ?? _traits['emotionTag'] as String? ?? '',
    );
    if (widget.source.provider != null) {
      _format =
          _traits['format'] as String? ??
          cloudTtsProfile(widget.source.provider!).formats.first;
    }
    if (widget.source.loadCatalog != null) unawaited(_loadCatalog());
  }

  Future<void> _loadCatalog() async {
    _catalogRequest?.cancel();
    final request = HttpTtsCancellation();
    _catalogRequest = request;
    setState(() {
      _loadingCatalog = true;
      _catalogError = null;
    });
    try {
      final catalog = await widget.source.loadCatalog!(request);
      if (!mounted || request.isCancelled) return;
      setState(() {
        _catalog = catalog;
        _voices = catalog
            .map(
              (v) => ReadAloudVoice(
                id: readAloudVoiceId(
                  widget.source.kind,
                  widget.source.id,
                  v.id,
                ),
                engineType: widget.source.kind,
                engineId: widget.source.id,
                speakerId: v.id,
                displayName: v.name,
                traitsJson: jsonEncode({'locale': v.locale}),
              ),
            )
            .toList();
        if (_speaker.text.isEmpty && _voices.isNotEmpty) {
          _selectVoice(_voices.first);
        }
      });
    } catch (error) {
      if (mounted && !request.isCancelled) {
        setState(() => _catalogError = '音色目录读取失败：$error');
      }
    } finally {
      if (mounted && !request.isCancelled) {
        setState(() => _loadingCatalog = false);
      }
    }
  }

  CloudTtsVoiceDescriptor? get _catalogVoice =>
      _catalog.where((v) => v.id == _speaker.text.trim()).firstOrNull;
  void _selectVoice(ReadAloudVoice voice) {
    _speaker.text = voice.speakerId;
    _name.text = voice.displayName;
    if (widget.source.kind == 'http') {
      _emotion.text = HttpTtsVoiceOptions(voice.traitsJson).emotionTag ?? '';
    } else if (widget.source.kind == 'cloud_tts') {
      final selected = _catalogVoice;
      if (selected != null) _locale.text = selected.locale;
      _style.clear();
      _role.clear();
    }
  }

  ReadAloudVoice? get _native =>
      _voices.where((v) => v.speakerId == _speaker.text.trim()).firstOrNull;

  List<Map<String, dynamic>> get _emotions => (jsonDecode(
    _native?.emotionCatalogJson ?? widget.voice?.emotionCatalogJson ?? '[]',
  ) as List).cast<Map<String, dynamic>>();

  ReadAloudVoice? _draft() {
    if (!_form.currentState!.validate()) return null;
    final source = widget.source;
    final speaker = _speaker.text.trim();
    final native = _voices.where((v) => v.speakerId == speaker).firstOrNull;
    final nativeTraits = native == null ? null : jsonDecode(native.traitsJson);
    final cloud = source.kind == 'cloud_tts';
    final traits = source.kind == 'http'
        ? HttpTtsVoiceOptions(
            native?.traitsJson ??
                (widget.voice == null ? '{}' : jsonEncode(_traits)),
          ).withEmotion(_emotion.text)
        : cloud
        ? <String, dynamic>{
            // 未展示的请求参数仍属于音色，不因重命名或试听而丢失。
            ..._traits,
            if (cloudTtsProfile(source.provider!).supportsLocale)
              'locale': _locale.text.trim(),
            if (cloudTtsProfile(source.provider!).supportsProsody) ...{
              if (cloudTtsProfile(source.provider!).supportsRole)
                'role': _role.text.trim(),
              'pitch': double.parse(_pitch.text),
              'volume': double.parse(_volume.text),
            },
            if (cloudTtsProfile(source.provider!).supportsSourceSpeed)
              'speed': double.parse(_speed.text),
            if (cloudTtsProfile(source.provider!).supportsStyle)
              'style': _style.text,
            if (source.provider == 'aws_polly')
              'sampleRate': int.tryParse(_sampleRate.text.trim()),
            if (cloudTtsProfile(source.provider!).supportsInstructions)
              'instructions': _instructions.text,
            'format': _format,
          }
        : <String, dynamic>{
            ..._traits,
            if (nativeTraits is Map) ...Map<String, dynamic>.from(nativeTraits),
          };
    return ReadAloudVoice(
      id: readAloudVoiceId(source.kind, source.id, speaker),
      engineType: source.kind,
      engineId: source.id,
      speakerId: speaker,
      displayName: _name.text.trim(),
      traitsJson: jsonEncode(traits),
      emotionCatalogJson:
          widget.voice?.emotionCatalogJson ??
          native?.emotionCatalogJson ??
          '[]',
      managedBy: 'user',
      enabled: widget.voice?.enabled ?? true,
      available: widget.voice?.available ?? true,
      excluded: widget.voice?.excluded ?? false,
    );
  }

  Future<void> _preview() async {
    final voice = _draft();
    if (voice == null || _sample.text.trim().isEmpty) return;
    setState(() => _previewing = true);
    try {
      await widget.onPreview(voice, _sample.text);
      if (mounted) setState(() => _error = null);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _previewing = false);
    }
  }

  @override
  void dispose() {
    _catalogRequest?.cancel();
    for (final c in [
      _speaker,
      _name,
      _speed,
      _style,
      _instructions,
      _sample,
      _emotion,
      _locale,
      _role,
      _pitch,
      _volume,
      _sampleRate,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final source = widget.source;
    final profile = source.provider == null
        ? null
        : cloudTtsProfile(source.provider!);
    return AppSettingsSheet(
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      title: widget.voice == null ? '添加音色' : '编辑音色',
      onSave: _previewing
          ? null
          : () {
              final voice = _draft();
              if (voice != null) Navigator.pop(context, voice);
            },
      child: Form(
        key: _form,
        child: AppSettingsForm(
          title: source.name,
          errorText: _error ?? _catalogError,
          children: [
            TextFormField(
              key: const ValueKey('voice-speaker'),
              controller: _speaker,
              readOnly: widget.voice != null || source.kind == 'system',
              decoration: const InputDecoration(labelText: '原生音色 ID'),
              validator: (v) => (v ?? '').trim().isEmpty ? '请选择音色' : null,
              onChanged: (_) => setState(() {
                _emotion.clear();
              }),
            ),
            if (_loadingCatalog) const LinearProgressIndicator(),
            if (_catalogError != null)
              TextButton(
                onPressed: _loadingCatalog ? null : _loadCatalog,
                child: const Text('重试获取音色'),
              ),
            if (widget.voice == null && _voices.isNotEmpty)
              Wrap(
                spacing: 4,
                runSpacing: 8,
                children: [
                  for (final v in _voices)
                    ActionChip(
                      label: Text(v.displayName),
                      onPressed: () {
                        setState(() {
                          _selectVoice(v);
                        });
                      },
                    ),
                ],
              ),
            TextFormField(
              key: const ValueKey('voice-name'),
              controller: _name,
              decoration: const InputDecoration(labelText: '音色名称'),
              validator: (v) => (v ?? '').trim().isEmpty ? '请输入音色名称' : null,
            ),
            if (source.kind == 'http') ...[
              TextFormField(
                key: const ValueKey('voice-emotion'),
                controller: _emotion,
                decoration: const InputDecoration(
                  labelText: '情感标签',
                  hintText: '留空使用引擎默认情感',
                ),
                validator: (value) {
                  final tag = value?.trim() ?? '';
                  if (tag.isNotEmpty &&
                      _emotions.isNotEmpty &&
                      _emotions.every((e) => e['emotionTag'] != tag)) {
                    return '请选择当前音色目录中的情感';
                  }
                  return null;
                },
              ),
              Wrap(
                spacing: 4,
                runSpacing: 8,
                children: [
                  ActionChip(
                    label: const Text('默认情感'),
                    onPressed: _emotion.clear,
                  ),
                  for (final emotion in _emotions)
                    ActionChip(
                      label: Text(emotion['emotionName'] as String),
                      onPressed: () =>
                          _emotion.text = emotion['emotionTag'] as String,
                    ),
                ],
              ),
            ],
            if (profile != null) ...[
              if (profile.supportsLocale)
                TextFormField(
                  key: const ValueKey('voice-locale'),
                  controller: _locale,
                  decoration: InputDecoration(
                    labelText: '语言',
                    hintText: profile.localeHint,
                  ),
                ),
              if (profile.supportsSourceSpeed)
                TextFormField(
                  key: const ValueKey('voice-speed'),
                  controller: _speed,
                  decoration: const InputDecoration(labelText: '合成语速'),
                  validator: (v) {
                    final n = double.tryParse(v ?? '');
                    return n == null ||
                            !n.isFinite ||
                            n < profile.sourceSpeedRange.min ||
                            n > profile.sourceSpeedRange.max
                        ? '${profile.sourceSpeedRange.min}–${profile.sourceSpeedRange.max}'
                        : null;
                  },
                ),
              if (profile.supportsStyle)
                TextFormField(
                  key: const ValueKey('voice-style'),
                  controller: _style,
                  decoration: InputDecoration(labelText: profile.styleLabel),
                ),
              if (profile.supportsStyle &&
                  (_catalogVoice?.styles ?? profile.styles).isNotEmpty)
                Wrap(
                  spacing: 4,
                  runSpacing: 8,
                  children: [
                    for (final style in _catalogVoice?.styles ?? profile.styles)
                      ActionChip(
                        label: Text(style),
                        onPressed: () => _style.text = style,
                      ),
                  ],
                ),
              if (profile.supportsProsody) ...[
                if (profile.supportsRole)
                  TextFormField(
                    key: const ValueKey('voice-role'),
                    controller: _role,
                    decoration: const InputDecoration(labelText: '角色'),
                  ),
                if (_catalogVoice?.roles.isNotEmpty ?? false)
                  Wrap(
                    spacing: 4,
                    runSpacing: 8,
                    children: [
                      for (final role in _catalogVoice!.roles)
                        ActionChip(
                          label: Text(role),
                          onPressed: () => _role.text = role,
                        ),
                    ],
                  ),
                for (final entry in {'音调': _pitch, '音量': _volume}.entries)
                  TextFormField(
                    key: ValueKey(
                      entry.key == '音调' ? 'voice-pitch' : 'voice-volume',
                    ),
                    controller: entry.value,
                    decoration: InputDecoration(labelText: entry.key),
                    validator: (v) {
                      final value = double.tryParse(v ?? '');
                      return value == null ||
                              !value.isFinite ||
                              value < profile.prosodyRange.min ||
                              value > profile.prosodyRange.max
                          ? '${profile.prosodyRange.min}–${profile.prosodyRange.max}'
                          : null;
                    },
                  ),
              ],
              if (profile.supportsInstructions)
                TextFormField(
                  key: const ValueKey('voice-instructions'),
                  controller: _instructions,
                  decoration: const InputDecoration(labelText: '朗读指令'),
                  maxLines: 3,
                ),
              DropdownButtonFormField<String>(
                initialValue: _format,
                key: const ValueKey('voice-format'),
                decoration: const InputDecoration(labelText: '音频格式'),
                items: [
                  for (final f in profile.formats)
                    DropdownMenuItem(value: f, child: Text(f)),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _format = v);
                },
              ),
            ],
            if (source.provider == 'aws_polly') ...[
              if (_catalogVoice?.supportedModels.isNotEmpty ?? false)
                Text('可用模型：${_catalogVoice!.supportedModels.join('、')}'),
              TextFormField(
                key: const ValueKey('voice-sample-rate'),
                controller: _sampleRate,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '采样率（Hz，留空使用默认值）'),
                validator: (text) {
                  if ((text ?? '').trim().isEmpty) return null;
                  final rate = int.tryParse(text!.trim());
                  final pcm = {'pcm', 'wav'}.contains(_format);
                  return (pcm
                              ? [8000, 16000]
                              : [8000, 16000, 22050, 24000, 44100, 48000])
                          .contains(rate)
                      ? null
                      : pcm
                      ? 'PCM/WAV 仅支持 8000、16000'
                      : '不支持的采样率';
                },
              ),
            ],
            TextFormField(
              key: const ValueKey('voice-preview-text'),
              controller: _sample,
              decoration: const InputDecoration(labelText: '试听文本'),
              maxLines: 3,
            ),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _previewing ? null : _preview,
                    icon: const Icon(Icons.play_arrow),
                    label: Text(_previewing ? '正在合成' : '试听'),
                  ),
                ),
                IconButton(
                  tooltip: '停止试听',
                  onPressed: widget.onStop,
                  icon: const Icon(Icons.stop),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
