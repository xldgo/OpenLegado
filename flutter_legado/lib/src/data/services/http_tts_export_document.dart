import 'dart:convert';

import '../../domain/contracts/read_aloud_voice_repository.dart';
import '../../models/models.dart';

/// 从当前持久化目录重建可交换文档，不导出设备凭据或系统语音。— Codex + Bridge
String httpTtsExportDocument(
  List<HttpTts> engines,
  List<ReadAloudVoice> voices,
) {
  return jsonEncode([
    for (final engine in engines)
      _engineDocument(
        engine,
        voices
            .where(
              (v) =>
                  v.engineType == 'http' &&
                  v.engineId == '${engine.id}' &&
                  v.available,
            )
            .toList(),
      ),
  ]);
}

Map<String, dynamic> _engineDocument(
  HttpTts engine,
  List<ReadAloudVoice> voices,
) {
  final emotions = <String, dynamic>{};
  for (final voice in voices) {
    for (final dynamic emotion
        in jsonDecode(voice.emotionCatalogJson) as List) {
      emotions[emotion['emotionTag'] as String] = emotion;
    }
  }
  return {
    ...engine.toJson(),
    if (voices.isNotEmpty)
      'speakersJson': jsonEncode([
        for (final voice in voices)
          {
            'speakerName': voice.displayName,
            'toneID': voice.speakerId,
            'tags': switch (jsonDecode(voice.traitsJson)) {
              List<dynamic> tags => tags,
              _ => <String>[],
            },
          },
      ]),
    if (emotions.isNotEmpty)
      'emotionsJson': jsonEncode(emotions.values.toList()),
  };
}
