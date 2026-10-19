import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import '../../domain/contracts/read_aloud_voice_repository.dart';
import '../../domain/contracts/cloud_tts_provider.dart';
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
  });
  final String kind, id, name;
  final String? provider;
  final List<ReadAloudVoice> voices;
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
      _emotion;
  String _format = 'wav';
  bool _previewing = false;
  String? _error;
  Map<String, dynamic> _traits = {};
  @override
  void initState() {
    super.initState();
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
  }

  ReadAloudVoice? get _native => widget.source.voices
      .where((v) => v.speakerId == _speaker.text.trim())
      .firstOrNull;

  List<Map<String, dynamic>> get _emotions => (jsonDecode(
    _native?.emotionCatalogJson ?? widget.voice?.emotionCatalogJson ?? '[]',
  ) as List).cast<Map<String, dynamic>>();

  ReadAloudVoice? _draft() {
    if (!_form.currentState!.validate()) return null;
    final source = widget.source;
    final speaker = _speaker.text.trim();
    final native = source.voices
        .where((v) => v.speakerId == speaker)
        .firstOrNull;
    final nativeTraits = native == null ? null : jsonDecode(native.traitsJson);
    final cloud = source.kind == 'cloud_tts';
    final traits = source.kind == 'http'
        ? HttpTtsVoiceOptions(
            native?.traitsJson ??
                (widget.voice == null ? '{}' : jsonEncode(_traits)),
          ).withEmotion(_emotion.text)
        : cloud
        ? <String, dynamic>{
            if (cloudTtsProfile(source.provider!).supportsSourceSpeed)
              'speed': double.parse(_speed.text),
            'style': _style.text,
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
    for (final c in [
      _speaker,
      _name,
      _speed,
      _style,
      _instructions,
      _sample,
      _emotion,
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
          errorText: _error,
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
            if (widget.voice == null && source.voices.isNotEmpty)
              Wrap(
                spacing: 4,
                runSpacing: 8,
                children: [
                  for (final v in source.voices)
                    ActionChip(
                      label: Text(v.displayName),
                      onPressed: () {
                        setState(() {
                          _speaker.text = v.speakerId;
                          _name.text = v.displayName;
                          if (source.kind == 'http') {
                            _emotion.text =
                                HttpTtsVoiceOptions(v.traitsJson).emotionTag ??
                                '';
                          }
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
              if (profile.supportsSourceSpeed)
                TextFormField(
                  key: const ValueKey('voice-speed'),
                  controller: _speed,
                  decoration: const InputDecoration(labelText: '合成语速'),
                  validator: (v) {
                    final n = double.tryParse(v ?? '');
                    return n == null || !n.isFinite || n < 0.25 || n > 4
                        ? '0.25–4.0'
                        : null;
                  },
                ),
              TextFormField(
                key: const ValueKey('voice-style'),
                controller: _style,
                decoration: const InputDecoration(labelText: '风格'),
              ),
              if (profile.styles.isNotEmpty)
                Wrap(
                  spacing: 4,
                  runSpacing: 8,
                  children: [
                    for (final style in profile.styles)
                      ActionChip(
                        label: Text(style),
                        onPressed: () => _style.text = style,
                      ),
                  ],
                ),
              TextFormField(
                key: const ValueKey('voice-instructions'),
                controller: _instructions,
                decoration: const InputDecoration(labelText: '朗读指令'),
                maxLines: 3,
              ),
              DropdownButtonFormField<String>(
                initialValue: _format,
                decoration: const InputDecoration(labelText: '音频格式'),
                items: [
                  for (final f in profile.formats)
                    DropdownMenuItem(value: f, child: Text(f)),
                ],
                onChanged: (v) {
                  if (v != null) _format = v;
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
