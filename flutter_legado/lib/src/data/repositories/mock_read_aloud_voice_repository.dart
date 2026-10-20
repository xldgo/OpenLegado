import 'dart:convert';

import '../../domain/contracts/read_aloud_voice_repository.dart';

/// Mock 会话内目录，不读取设备或伪造原生文件。— Codex + Bridge
final class MockReadAloudVoiceRepository implements ReadAloudVoiceRepository {
  MockReadAloudVoiceRepository({this.supportsCatalog = true});
  @override
  final bool supportsCatalog;
  final _voices = <ReadAloudVoice>[];
  @override
  Future<List<ReadAloudVoice>> list() async => List.unmodifiable(_voices);
  String _id(String kind, String engine, String speaker) =>
      readAloudVoiceId(kind, engine, speaker);
  @override
  Future<void> save(ReadAloudVoice voice) async {
    if (!{'http', 'system', 'cloud_tts'}.contains(voice.engineType) ||
        voice.speakerId.trim().isEmpty ||
        voice.displayName.trim().isEmpty ||
        voice.id !=
            readAloudVoiceId(
              voice.engineType,
              voice.engineId,
              voice.speakerId,
            ) ||
        jsonDecode(voice.traitsJson) is! Map ||
        jsonDecode(voice.emotionCatalogJson) is! List) {
      throw const FormatException('音色配置无效');
    }
    final previous = _voices.where((v) => v.id == voice.id).firstOrNull;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _voices.removeWhere((v) => v.id == voice.id);
    _voices.add(
      ReadAloudVoice.fromJson({
        ...voice.toJson(),
        'managedBy': 'user',
        'createdAt': previous?.createdAt ?? timestamp,
        'updatedAt': timestamp,
        'revision': (previous?.revision ?? 0) + 1,
      }),
    );
  }

  @override
  Future<void> delete(String id) async {
    if (!_voices.any((v) => v.id == id && v.managedBy == 'user')) {
      throw StateError('用户音色不存在');
    }
    _voices.removeWhere((v) => v.id == id);
  }

  void clearCloud(String id) => _voices.removeWhere(
    (v) => v.engineType == 'cloud_tts' && v.engineId == id,
  );
  void _sync(
    String kind,
    String engine,
    List<({String speaker, String name, String traits})> incoming,
    String emotions,
  ) {
    final ids = <String>{};
    for (final e in incoming) {
      final id = _id(kind, engine, e.speaker);
      if (!ids.add(id)) continue;
      final i = _voices.indexWhere((v) => v.id == id);
      if (i < 0) {
        _voices.add(
          ReadAloudVoice(
            id: id,
            engineType: kind,
            engineId: engine,
            speakerId: e.speaker,
            displayName: e.name,
            traitsJson: e.traits,
            emotionCatalogJson: emotions,
            managedBy: kind == 'http'
                ? 'http_source_catalog'
                : 'system_catalog',
          ),
        );
      } else if (_voices[i].managedBy == 'user') {
        _voices[i] = _voices[i].copyWith(available: true);
      } else {
        _voices[i] = _voices[i].copyWith(
          displayName: e.name,
          traitsJson: e.traits,
          emotionCatalogJson: emotions,
          available: true,
        );
      }
    }
    if (kind == 'http') {
      for (var i = 0; i < _voices.length; i++) {
        final v = _voices[i];
        if (v.engineType == kind &&
            v.engineId == engine &&
            v.managedBy == 'user' &&
            !ids.contains(v.id)) {
          _voices[i] = v.copyWith(available: false);
        }
      }
      _voices.removeWhere(
        (v) =>
            v.engineType == kind &&
            v.engineId == engine &&
            v.managedBy != 'user' &&
            !ids.contains(v.id),
      );
    } else {
      for (var i = 0; i < _voices.length; i++) {
        final v = _voices[i];
        if (v.engineType == kind &&
            v.engineId == engine &&
            !ids.contains(v.id)) {
          _voices[i] = v.copyWith(available: false);
        }
      }
    }
  }

  @override
  Future<void> syncSystem(
    String engineId,
    List<SystemVoiceCatalogEntry> entries,
  ) async {
    if (!engineId.startsWith('system:') ||
        entries.any(
          (e) => e.speakerId.trim().isEmpty || e.displayName.trim().isEmpty,
        )) {
      throw const FormatException('系统音色目录无效');
    }
    for (final e in entries) {
      jsonDecode(e.traitsJson);
    }
    _sync('system', engineId, [
      for (final e in entries)
        (speaker: e.speakerId, name: e.displayName, traits: e.traitsJson),
    ], '[]');
  }

  @override
  Future<void> setFlags(
    String id, {
    required bool enabled,
    required bool excluded,
  }) async {
    final i = _voices.indexWhere((v) => v.id == id);
    if (i < 0) throw StateError('音色不存在');
    _voices[i] = _voices[i].copyWith(enabled: enabled, excluded: excluded);
  }

  void clearHttp(int id) =>
      _voices.removeWhere((v) => v.engineType == 'http' && v.engineId == '$id');
  void importHttp(int id, Map<String, dynamic> raw) {
    List<Map<String, dynamic>> flatten(Object? value) {
      if (value is! String) return [];
      Object? parsed;
      try {
        parsed = jsonDecode(value);
      } catch (_) {
        return [];
      }
      final flat = <Map<String, dynamic>>[], groups = <Map<String, dynamic>>[];
      for (final item in parsed is List ? parsed : [parsed]) {
        if (item is! Map) continue;
        final j = Map<String, dynamic>.from(item);
        if (j['items'] is List) {
          groups.addAll(
            (j['items'] as List).whereType<Map>().map(
              (v) => Map<String, dynamic>.from(v),
            ),
          );
        } else {
          flat.add(j);
        }
      }
      return [...flat, ...groups];
    }

    String? field(Map<String, dynamic> j, List<String> keys) {
      for (final k in keys) {
        final v = j[k];
        if (v is String || v is num || v is bool) {
          if (v.toString().trim().isNotEmpty) return v.toString();
        }
      }
      return null;
    }

    final speakers = <({String speaker, String name, String traits})>[];
    final ids = <String>{};
    for (final j in flatten(raw['speakersJson'])) {
      final id = field(j, ['toneID', 'toneId', 'tone_id']),
          name = field(j, ['speakerName', 'name']);
      if (id != null && name != null && ids.add(id)) {
        speakers.add((
          speaker: id,
          name: name,
          traits: jsonEncode(
            (j['tags'] is List ? j['tags'] as List : [])
                .where((v) => v is String || v is num || v is bool)
                .map((v) => v.toString())
                .where((v) => v.trim().isNotEmpty)
                .toList(),
          ),
        ));
      }
    }
    if (speakers.isEmpty) return;
    final emotions = <Map<String, String>>[];
    final tags = <String>{};
    for (final j in flatten(raw['emotionsJson'])) {
      final tag = field(j, ['emotionTag', 'tag', 'value']),
          name = field(j, ['emotionName', 'name']);
      if (tag != null && name != null && tags.add(tag)) {
        emotions.add({'emotionName': name, 'emotionTag': tag});
      }
    }
    _sync('http', '$id', speakers, jsonEncode(emotions));
  }
}
